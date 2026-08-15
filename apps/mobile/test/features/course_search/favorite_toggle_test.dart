// Tapping the heart on a search result.
//
// _onToggleFavorite only ever did the work when the state was
// CourseSearchFavoritesLoaded — that is, only on the Favourites tab itself. On
// the All tab it reached a branch that called isFavorite and threw the answer
// away: nothing added, nothing removed, and the heart stayed hollow however
// many times it was tapped.

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/repositories/course_search_repository.dart';
import 'package:vsp_mobile/domain/models/course_search_result.dart';
import 'package:vsp_mobile/domain/models/favorite_course.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_bloc.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_event.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_state.dart';

class _FakeRepo implements CourseSearchRepository {
  final added = <int>[];
  final removed = <int>[];
  bool failNext = false;

  @override
  Future<void> addFavorite(int courseId) async {
    if (failNext) throw Exception('server said no');
    added.add(courseId);
  }

  @override
  Future<void> removeFavorite(int courseId) async {
    if (failNext) throw Exception('server said no');
    removed.add(courseId);
  }

  @override
  Future<List<FavoriteCourse>> getFavorites({bool forceReload = false}) async =>
      const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CourseSearchLoaded loadedWith(Set<int> favorites) => CourseSearchLoaded(
  results: const <CourseSearchResult>[],
  page: 0,
  hasNext: false,
  activeTab: SearchTab.all,
  favoriteCourseIds: favorites,
);

void main() {
  group('the heart on a search result', () {
    late _FakeRepo repo;
    late CourseSearchBloc bloc;

    setUp(() {
      repo = _FakeRepo();
      bloc = CourseSearchBloc(repository: repo);
    });

    test('adds a favourite from the All tab', () async {
      bloc.emit(loadedWith(const {}));

      bloc.add(const ToggleFavorite(1351));
      await Future<void>.delayed(Duration.zero);

      expect(repo.added, [1351]);
      expect((bloc.state as CourseSearchLoaded).favoriteCourseIds,
          contains(1351));
    });

    test('removes one that is already favourited', () async {
      bloc.emit(loadedWith(const {1351}));

      bloc.add(const ToggleFavorite(1351));
      await Future<void>.delayed(Duration.zero);

      expect(repo.removed, [1351]);
      expect((bloc.state as CourseSearchLoaded).favoriteCourseIds,
          isNot(contains(1351)));
    });

    /// A heart left filled over a favourite the server never took is a lie the
    /// golfer finds out about later, on another screen.
    test('puts the heart back when the server refuses', () async {
      repo.failNext = true;
      bloc.emit(loadedWith(const {}));

      bloc.add(const ToggleFavorite(1351));
      await Future<void>.delayed(Duration.zero);

      expect((bloc.state as CourseSearchLoaded).favoriteCourseIds,
          isNot(contains(1351)));
    });
  });
}
