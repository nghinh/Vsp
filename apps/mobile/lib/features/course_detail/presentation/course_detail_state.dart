// Course Detail State — VSP Mobile App
//
// State classes for CourseDetailBloc.

import 'package:equatable/equatable.dart';

import '../../../domain/models/course_detail.dart';

/// Base state for course detail.
abstract class CourseDetailState extends Equatable {
  const CourseDetailState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no course loaded yet.
class CourseDetailInitial extends CourseDetailState {
  const CourseDetailInitial();
}

/// Loading state.
class CourseDetailLoading extends CourseDetailState {
  const CourseDetailLoading();
}

/// Loaded state.
class CourseDetailLoaded extends CourseDetailState {
  final CourseDetail course;

  const CourseDetailLoaded(this.course);

  @override
  List<Object?> get props => [course];
}

/// Error state.
class CourseDetailError extends CourseDetailState {
  final String message;
  final CourseDetail? lastCourse;

  const CourseDetailError({required this.message, this.lastCourse});

  @override
  List<Object?> get props => [message, lastCourse];
}
