// Course Detail BLoC — VSP Mobile App
//
// State management for CourseDetailScreen.

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/course_detail_repository.dart';
import 'course_detail_event.dart';
import 'course_detail_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// BLoC for course detail screen.
class CourseDetailBloc extends Bloc<CourseDetailEvent, CourseDetailState> {
  final CourseDetailRepository _repository;

  /// The course ID being displayed — set on LoadCourseDetail.
  int? _courseId;

  CourseDetailBloc({required CourseDetailRepository repository})
    : _repository = repository,
      super(const CourseDetailInitial()) {
    on<LoadCourseDetail>(_onLoadCourseDetail);
    on<RefreshCourseDetail>(_onRefreshCourseDetail);
  }

  Future<void> _onLoadCourseDetail(
    LoadCourseDetail event,
    Emitter<CourseDetailState> emit,
  ) async {
    _courseId = event.courseId;
    emit(const CourseDetailLoading());

    try {
      final course = await _repository.getCourseDetail(event.courseId);
      emit(CourseDetailLoaded(course));
    } catch (ex) {
      emit(CourseDetailError(message: AppMessages.courseDetailLoadFailed));
    }
  }

  Future<void> _onRefreshCourseDetail(
    RefreshCourseDetail event,
    Emitter<CourseDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is CourseDetailLoaded) {
      // Refresh the currently-shown course; keep showing current data on failure.
      final courseId = _courseId ?? currentState.course.courseId;
      _courseId = courseId;
      try {
        final course = await _repository.getCourseDetail(courseId);
        emit(CourseDetailLoaded(course));
      } catch (_) {
        // Refresh failed — keep showing current data
      }
    } else if (_courseId != null) {
      add(LoadCourseDetail(_courseId!));
    }
  }
}
