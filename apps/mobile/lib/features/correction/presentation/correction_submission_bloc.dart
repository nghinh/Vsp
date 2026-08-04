// CorrectionSubmissionBloc — VSP Mobile App
//
// BLoC for the correction submission form.
//
// Per Story 9.1 Slice 3: Submission form UI.
//
// Handles:
// - Loading current GPS location for the form.
// - Submitting a correction (offline-first: writes to SQLite, queues sync event).

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/qualified_location.dart';
import '../../../domain/services/location_service.dart';
import '../domain/course_correction.dart';
import '../../../data/repositories/course_correction_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class CorrectionSubmissionEvent extends Equatable {
  const CorrectionSubmissionEvent();

  @override
  List<Object?> get props => [];
}

/// Load the form — capture GPS location.
class LoadCorrectionForm extends CorrectionSubmissionEvent {
  final String courseId;
  final String? holeId;

  const LoadCorrectionForm({required this.courseId, this.holeId});

  @override
  List<Object?> get props => [courseId, holeId];
}

/// Submit a correction report.
class SubmitCorrection extends CorrectionSubmissionEvent {
  final CorrectionIssueType issueType;
  final String? note;
  final String courseId;
  final String? holeId;
  final double reporterLat;
  final double reporterLng;
  final double gpsAccuracy;

  const SubmitCorrection({
    required this.issueType,
    this.note,
    required this.courseId,
    this.holeId,
    required this.reporterLat,
    required this.reporterLng,
    required this.gpsAccuracy,
  });

  @override
  List<Object?> get props => [
    issueType,
    note,
    courseId,
    holeId,
    reporterLat,
    reporterLng,
    gpsAccuracy,
  ];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class CorrectionSubmissionState extends Equatable {
  const CorrectionSubmissionState();

  @override
  List<Object?> get props => [];
}

/// Initial / empty state.
class CorrectionSubmissionInitial extends CorrectionSubmissionState {
  const CorrectionSubmissionInitial();
}

/// Loading form data (capturing GPS).
class CorrectionSubmissionLoading extends CorrectionSubmissionState {
  const CorrectionSubmissionLoading();
}

/// Form ready with location captured.
class CorrectionFormReady extends CorrectionSubmissionState {
  final String courseId;
  final String? holeId;
  final QualifiedLocation? location;

  const CorrectionFormReady({
    required this.courseId,
    this.holeId,
    this.location,
  });

  @override
  List<Object?> get props => [courseId, holeId, location];
}

/// Correction submitted successfully (offline).
class CorrectionSubmissionSuccess extends CorrectionSubmissionState {
  final CourseCorrection correction;

  const CorrectionSubmissionSuccess({required this.correction});

  @override
  List<Object?> get props => [correction];
}

/// Correction submission failed.
class CorrectionSubmissionFailure extends CorrectionSubmissionState {
  final String message;

  const CorrectionSubmissionFailure({required this.message});

  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

class CorrectionSubmissionBloc
    extends Bloc<CorrectionSubmissionEvent, CorrectionSubmissionState> {
  final CourseCorrectionRepository _repository;
  final LocationService _locationService;
  final Uuid _uuid;

  CorrectionSubmissionBloc({
    required CourseCorrectionRepository repository,
    required LocationService locationService,
    Uuid? uuid,
  }) : _repository = repository,
       _locationService = locationService,
       _uuid = uuid ?? const Uuid(),
       super(const CorrectionSubmissionInitial()) {
    on<LoadCorrectionForm>(_onLoadForm);
    on<SubmitCorrection>(_onSubmit);
  }

  Future<void> _onLoadForm(
    LoadCorrectionForm event,
    Emitter<CorrectionSubmissionState> emit,
  ) async {
    emit(const CorrectionSubmissionLoading());

    try {
      // Capture current GPS location.
      final location = await _locationService.getCurrentLocation();
      emit(
        CorrectionFormReady(
          courseId: event.courseId,
          holeId: event.holeId,
          location: location,
        ),
      );
    } catch (e) {
      // Even if GPS fails, the form is still usable (manual or last-known location).
      emit(
        CorrectionFormReady(
          courseId: event.courseId,
          holeId: event.holeId,
          location: null,
        ),
      );
    }
  }

  Future<void> _onSubmit(
    SubmitCorrection event,
    Emitter<CorrectionSubmissionState> emit,
  ) async {
    emit(const CorrectionSubmissionLoading());

    try {
      final id = _uuid.v4();
      final idempotencyKey = _uuid.v4();

      final correction = CourseCorrection(
        id: id,
        courseId: event.courseId,
        holeId: event.holeId,
        issueType: event.issueType,
        reporterLat: event.reporterLat,
        reporterLng: event.reporterLng,
        gpsAccuracy: event.gpsAccuracy,
        submittedAt: DateTime.now().toUtc(),
        note: event.note?.isNotEmpty == true ? event.note : null,
        syncState: CorrectionSyncState.pending,
        idempotencyKey: idempotencyKey,
      );

      // Validate before submitting.
      if (!correction.isValid) {
        emit(
          CorrectionSubmissionFailure(
            message: correction.validate().join(', '),
          ),
        );
        return;
      }

      final result = await _repository.submitCorrection(correction);

      // NOTE: The sync event is returned to the caller (e.g. the screen or
      // a sync service) which is responsible for enqueueing it to the sync worker.
      // This follows the same pattern as ScoreRepositoryImpl — the repository
      // writes locally and returns the event; the UI layer dispatches it.

      emit(CorrectionSubmissionSuccess(correction: result.correction));
    } catch (e) {
      emit(
        CorrectionSubmissionFailure(message: 'Failed to submit correction: $e'),
      );
    }
  }
}
