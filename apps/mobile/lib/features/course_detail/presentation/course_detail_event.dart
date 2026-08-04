// Course Detail Events — VSP Mobile App
//
// Events for CourseDetailBloc.

import 'package:equatable/equatable.dart';

/// Base event for course detail.
abstract class CourseDetailEvent extends Equatable {
  const CourseDetailEvent();

  @override
  List<Object?> get props => [];
}

/// Load course detail.
class LoadCourseDetail extends CourseDetailEvent {
  final int courseId;

  const LoadCourseDetail(this.courseId);

  @override
  List<Object?> get props => [courseId];
}

/// Refresh course detail (pull-to-refresh).
class RefreshCourseDetail extends CourseDetailEvent {
  const RefreshCourseDetail();
}
