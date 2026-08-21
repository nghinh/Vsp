// A dead session is not a failed search.
//
// The picker answered a 401 with "Đã có lỗi xảy ra / Tìm kiếm thất bại. Vui
// lòng thử lại." and a Thử lại button. By the time a 401 reaches the bloc,
// ApiClient has already spent the refresh token on it, so there is no token
// left to try with: every tap walks into the same wall, and the golfer's only
// way out is to guess that signing out is what the app meant. Reported from a
// phone on 21/8/2026, one day after the same fix landed on the profile screen.
//
// What must not change is the other half: a 500, a timeout, a broken payload
// are all worth retrying, and must still say so.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_bloc.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_event.dart';
import 'package:vsp_mobile/features/course_search/presentation/course_search_state.dart';

import 'presentation/mocks/mock_course_search_repository.dart';

const _unauthorized = VspApiException(
  code: 'UNAUTHORIZED',
  message: 'Unauthorized',
  statusCode: 401,
);

const _serverBroke = VspApiException(
  code: 'INTERNAL_ERROR',
  message: 'Internal error',
  statusCode: 500,
);

void main() {
  late MockCourseSearchRepository repository;

  setUp(() {
    repository = MockCourseSearchRepository();
    // A refused refresh has already run AuthRepository.logout, which clears
    // this. Its absence is what says the session is spent rather than
    // unreachable — see CourseSearchBloc._sessionIsOver.
    ApiClient().setAccessToken(null);
  });

  group('searching with a session that is over', () {
    blocTest<CourseSearchBloc, CourseSearchState>(
      'says the session ended rather than offering a retry',
      build: () {
        repository.mockSearchError = _unauthorized;
        return CourseSearchBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const SearchSubmitted('Long Biên')),
      expect: () => [
        isA<CourseSearchLoading>(),
        isA<CourseSearchSessionExpired>().having(
          (s) => s.activeTab,
          'activeTab',
          SearchTab.all,
        ),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'the favourites tab reaches the same conclusion',
      build: () {
        repository.mockGetFavoritesError = _unauthorized;
        return CourseSearchBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const LoadFavorites()),
      expect: () => [
        isA<CourseSearchFavoritesLoaded>(),
        isA<CourseSearchSessionExpired>().having(
          (s) => s.activeTab,
          'activeTab',
          SearchTab.favorites,
        ),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'and so does the recent tab',
      build: () {
        repository.mockGetRecentCoursesError = _unauthorized;
        return CourseSearchBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const LoadRecent()),
      expect: () => [
        isA<CourseSearchRecentLoaded>(),
        isA<CourseSearchSessionExpired>(),
      ],
    );
  });

  group('a failure that is worth another try', () {
    blocTest<CourseSearchBloc, CourseSearchState>(
      'still offers one, and does not sign the golfer out',
      build: () {
        repository.mockSearchError = _serverBroke;
        return CourseSearchBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const SearchSubmitted('Long Biên')),
      expect: () => [
        isA<CourseSearchLoading>(),
        isA<CourseSearchError>(),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'a 401 the phone could not refresh, because it has no signal',
      // The refresh never reached the server, so the stored session is intact
      // and the token is still installed. Ejecting this golfer would destroy a
      // session the server would still honour — on a course, where losing
      // signal is the normal condition and the login screen is unreachable.
      build: () {
        ApiClient().setAccessToken('still-a-session');
        repository.mockSearchError = _unauthorized;
        return CourseSearchBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const SearchSubmitted('Long Biên')),
      expect: () => [
        isA<CourseSearchLoading>(),
        isA<CourseSearchError>(),
      ],
    );

    blocTest<CourseSearchBloc, CourseSearchState>(
      'including a plain network failure with no status at all',
      build: () {
        repository.mockSearchError = Exception('SocketException');
        return CourseSearchBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const SearchSubmitted('')),
      expect: () => [
        isA<CourseSearchLoading>(),
        isA<CourseSearchError>(),
      ],
    );
  });
}
