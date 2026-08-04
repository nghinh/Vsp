// Course Detail BLoC Tests — VSP Mobile App

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/data/repositories/course_detail_repository.dart';
import 'package:vsp_mobile/domain/models/course_detail.dart';
import 'package:vsp_mobile/features/course_detail/presentation/course_detail_bloc.dart';
import 'package:vsp_mobile/features/course_detail/presentation/course_detail_event.dart';
import 'package:vsp_mobile/features/course_detail/presentation/course_detail_state.dart';

import '../mocks/mock_course_detail_repository.dart';

void main() {
  group('CourseDetailBloc', () {
    late CourseDetailRepository repository;

    setUp(() {
      repository = MockCourseDetailRepository();
    });

    CourseDetail makeCourseDetail({String facilityName = 'Test Golf Course'}) =>
        CourseDetail.fromJson({
      'courseId': 1,
      'facilityId': 10,
      'facilityName': facilityName,
      'latitude': 21.0285,
      'longitude': 105.8542,
      'holesCount': 18,
      'parTotal': 72,
      'imageUrls': [],
      'facilities': [],
      'localRules': [],
      'holes': [],
      'teeSets': [],
      'conditions': [],
    });

    test('initial state is CourseDetailInitial', () {
      final bloc = CourseDetailBloc(repository: repository);
      expect(bloc.state, isA<CourseDetailInitial>());
      bloc.close();
    });

    blocTest<CourseDetailBloc, CourseDetailState>(
      'emits [Loading, Loaded] on LoadCourseDetail success',
      setUp: () {
        (repository as MockCourseDetailRepository).mockCourseDetail =
            makeCourseDetail();
      },
      build: () => CourseDetailBloc(repository: repository),
      act: (bloc) => bloc.add(const LoadCourseDetail(1)),
      expect: () => [isA<CourseDetailLoading>(), isA<CourseDetailLoaded>()],
    );

    blocTest<CourseDetailBloc, CourseDetailState>(
      'emits [Loading, Error] on LoadCourseDetail failure',
      setUp: () {
        (repository as MockCourseDetailRepository).mockException = Exception(
          'Network error',
        );
      },
      build: () => CourseDetailBloc(repository: repository),
      act: (bloc) => bloc.add(const LoadCourseDetail(1)),
      expect: () => [isA<CourseDetailLoading>(), isA<CourseDetailError>()],
    );

    blocTest<CourseDetailBloc, CourseDetailState>(
      'emits Loaded with new data on RefreshCourseDetail',
      setUp: () {
        final repo = repository as MockCourseDetailRepository;
        // Refresh returns distinct data so the new Loaded state is not de-duped.
        repo.mockCourseDetail = makeCourseDetail(facilityName: 'Refreshed Course');
      },
      build: () => CourseDetailBloc(repository: repository),
      seed: () => CourseDetailLoaded(makeCourseDetail()),
      // Refresh derives the course id from the currently-loaded state.
      act: (bloc) => bloc.add(const RefreshCourseDetail()),
      expect: () => [isA<CourseDetailLoaded>()],
    );

    test('CourseDetailLoaded state contains correct course', () {
      final course = makeCourseDetail();
      final state = CourseDetailLoaded(course);
      expect(state.course.courseId, 1);
      expect(state.course.facilityName, 'Test Golf Course');
    });

    test('CourseDetailError state contains message', () {
      final state = CourseDetailError(message: 'Failed to load');
      expect(state.message, 'Failed to load');
      expect(state.lastCourse, isNull);
    });

    test('CourseDetailError state preserves lastCourse', () {
      final course = makeCourseDetail();
      final state = CourseDetailError(
        message: 'Failed to load',
        lastCourse: course,
      );
      expect(state.lastCourse, isNotNull);
      expect(state.lastCourse!.courseId, 1);
    });
  });
}
