// CorrectionListBloc — VSP Mobile App
//
// BLoC for the "My Corrections" list screen.
//
// Per Story 9.1 Slice 4: My corrections list UI.
//
// Handles:
// - Loading corrections for the current user.
// - Refreshing from local DB (sync queue state is reflected on reload).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/course_correction.dart';
import '../../../data/repositories/course_correction_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class CorrectionListEvent extends Equatable {
  const CorrectionListEvent();

  @override
  List<Object?> get props => [];
}

/// Load corrections for a course (or all if courseId is null).
class LoadCorrections extends CorrectionListEvent {
  final String? courseId;

  const LoadCorrections({this.courseId});

  @override
  List<Object?> get props => [courseId];
}

/// Refresh — re-queries local DB to pick up sync state changes.
class RefreshCorrections extends CorrectionListEvent {
  const RefreshCorrections();
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class CorrectionListState extends Equatable {
  const CorrectionListState();

  @override
  List<Object?> get props => [];
}

/// Initial state.
class CorrectionListInitial extends CorrectionListState {
  const CorrectionListInitial();
}

/// Loading corrections.
class CorrectionListLoading extends CorrectionListState {
  const CorrectionListLoading();
}

/// Corrections loaded successfully.
class CorrectionListLoaded extends CorrectionListState {
  final List<CourseCorrection> corrections;

  const CorrectionListLoaded({required this.corrections});

  @override
  List<Object?> get props => [corrections];
}

/// No corrections found.
class CorrectionListEmpty extends CorrectionListState {
  const CorrectionListEmpty();
}

/// Error loading corrections.
class CorrectionListError extends CorrectionListState {
  final String message;

  const CorrectionListError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

class CorrectionListBloc
    extends Bloc<CorrectionListEvent, CorrectionListState> {
  final CourseCorrectionRepository _repository;
  String? _lastCourseId;

  CorrectionListBloc({required CourseCorrectionRepository repository})
    : _repository = repository,
      super(const CorrectionListInitial()) {
    on<LoadCorrections>(_onLoad);
    on<RefreshCorrections>(_onRefresh);
  }

  Future<void> _onLoad(
    LoadCorrections event,
    Emitter<CorrectionListState> emit,
  ) async {
    emit(const CorrectionListLoading());
    _lastCourseId = event.courseId;

    try {
      List<CourseCorrection> corrections;
      if (event.courseId != null) {
        corrections = await _repository.getCorrectionsForCourse(
          event.courseId!,
        );
      } else {
        // Load all corrections — query by all states.
        final all = await Future.wait([
          _repository.getCorrectionsByState(CorrectionSyncState.pending),
          _repository.getCorrectionsByState(CorrectionSyncState.submitted),
          _repository.getCorrectionsByState(CorrectionSyncState.accepted),
          _repository.getCorrectionsByState(CorrectionSyncState.rejected),
        ]);
        corrections = all.expand((list) => list).toList();
        // Sort by submittedAt descending.
        corrections.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      }

      if (corrections.isEmpty) {
        emit(const CorrectionListEmpty());
      } else {
        emit(CorrectionListLoaded(corrections: corrections));
      }
    } catch (e) {
      emit(CorrectionListError(message: 'Failed to load corrections: $e'));
    }
  }

  Future<void> _onRefresh(
    RefreshCorrections event,
    Emitter<CorrectionListState> emit,
  ) async {
    // Re-dispatch load with the last known courseId.
    add(LoadCorrections(courseId: _lastCourseId));
  }
}
