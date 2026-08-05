// Privacy BLoC — VSP Mobile App
//
// State management for privacy request submission and status tracking.
//
// Events: LoadPrivacyRequests, SubmitDataExportRequest, SubmitAccountDeletionRequest,
//         SubmitRoundDeletionRequest, LoadRequestDetail, ClearSubmissionResult
// States: PrivacyInitial, PrivacyLoading, PrivacyRequestsLoaded, PrivacyRequestDetailLoaded,
//         PrivacySubmitting, PrivacySubmissionSuccess, PrivacySubmissionError, PrivacyError
//
// AC-3: Users can request data export, account deletion, round deletion with status tracking.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/privacy_request_dto.dart';
import '../data/privacy_repository.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Events ─────────────────────────────────────────────────────────────────

/// Base event for PrivacyBloc.
abstract class PrivacyEvent extends Equatable {
  const PrivacyEvent();

  @override
  List<Object?> get props => [];
}

/// Load all privacy requests for the current golfer.
class LoadPrivacyRequests extends PrivacyEvent {
  final bool forceReload;

  const LoadPrivacyRequests({this.forceReload = false});

  @override
  List<Object?> get props => [forceReload];
}

/// Submit a data export request.
class SubmitDataExportRequest extends PrivacyEvent {
  const SubmitDataExportRequest();
}

/// Submit an account deletion request.
class SubmitAccountDeletionRequest extends PrivacyEvent {
  const SubmitAccountDeletionRequest();
}

/// Submit a round deletion request.
class SubmitRoundDeletionRequest extends PrivacyEvent {
  final String targetRoundId;

  const SubmitRoundDeletionRequest({required this.targetRoundId});

  @override
  List<Object?> get props => [targetRoundId];
}

/// Load a specific privacy request detail.
class LoadRequestDetail extends PrivacyEvent {
  final int requestId;

  const LoadRequestDetail({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

/// Clear the submission result (dismiss success/error banner).
class ClearSubmissionResult extends PrivacyEvent {
  const ClearSubmissionResult();
}

// ─── States ──────────────────────────────────────────────────────────────────

/// Base state for PrivacyBloc.
abstract class PrivacyState extends Equatable {
  const PrivacyState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no requests loaded yet.
class PrivacyInitial extends PrivacyState {
  const PrivacyInitial();
}

/// Loading privacy requests.
class PrivacyLoading extends PrivacyState {
  const PrivacyLoading();
}

/// Privacy requests loaded successfully.
class PrivacyRequestsLoaded extends PrivacyState {
  final List<PrivacyRequestDTO> requests;
  final PrivacySubmissionResult? submissionResult;

  const PrivacyRequestsLoaded({required this.requests, this.submissionResult});

  PrivacyRequestsLoaded copyWith({
    List<PrivacyRequestDTO>? requests,
    PrivacySubmissionResult? submissionResult,
    bool clearSubmissionResult = false,
  }) {
    return PrivacyRequestsLoaded(
      requests: requests ?? this.requests,
      submissionResult: clearSubmissionResult
          ? null
          : (submissionResult ?? this.submissionResult),
    );
  }

  @override
  List<Object?> get props => [requests, submissionResult];
}

/// Single privacy request detail loaded.
class PrivacyRequestDetailLoaded extends PrivacyState {
  final PrivacyRequestDTO request;

  const PrivacyRequestDetailLoaded({required this.request});

  @override
  List<Object?> get props => [request];
}

/// Error loading or managing privacy requests.
class PrivacyError extends PrivacyState {
  final String message;
  final List<PrivacyRequestDTO>? lastRequests;

  const PrivacyError({required this.message, this.lastRequests});

  @override
  List<Object?> get props => [message, lastRequests];
}

/// Result of a submission attempt.
class PrivacySubmissionResult extends Equatable {
  final bool wasSuccess;
  final PrivacyRequestDTO? request;
  final String? errorMessage;
  final PrivacyRequestType? submittedType;

  const PrivacySubmissionResult.success({required this.request})
    : wasSuccess = true,
      errorMessage = null,
      submittedType = null;

  const PrivacySubmissionResult.failure({
    required this.errorMessage,
    this.submittedType,
  }) : wasSuccess = false,
       request = null;

  @override
  List<Object?> get props => [wasSuccess, request, errorMessage, submittedType];
}

// ─── BLoC ────────────────────────────────────────────────────────────────────

class PrivacyBloc extends Bloc<PrivacyEvent, PrivacyState> {
  final PrivacyRepository _repository;

  /// Cached list of requests for reloading.
  List<PrivacyRequestDTO> _cachedRequests = [];

  PrivacyBloc({required PrivacyRepository repository})
    : _repository = repository,
      super(const PrivacyInitial()) {
    on<LoadPrivacyRequests>(_onLoadPrivacyRequests);
    on<SubmitDataExportRequest>(_onSubmitDataExportRequest);
    on<SubmitAccountDeletionRequest>(_onSubmitAccountDeletionRequest);
    on<SubmitRoundDeletionRequest>(_onSubmitRoundDeletionRequest);
    on<LoadRequestDetail>(_onLoadRequestDetail);
    on<ClearSubmissionResult>(_onClearSubmissionResult);
  }

  Future<void> _onLoadPrivacyRequests(
    LoadPrivacyRequests event,
    Emitter<PrivacyState> emit,
  ) async {
    // Show loading only on first load or force reload
    if (_cachedRequests.isEmpty || event.forceReload) {
      emit(const PrivacyLoading());
    }

    try {
      final requests = await _repository.getMyRequests();
      _cachedRequests = requests;
      emit(PrivacyRequestsLoaded(requests: requests));
    } catch (ex) {
      emit(
        PrivacyError(
          message: AppMessages.privacyLoadFailed,
          lastRequests: _cachedRequests.isNotEmpty ? _cachedRequests : null,
        ),
      );
    }
  }

  Future<void> _onSubmitDataExportRequest(
    SubmitDataExportRequest event,
    Emitter<PrivacyState> emit,
  ) async {
    final currentState = state;
    if (currentState is PrivacyRequestsLoaded) {
      emit(
        PrivacyRequestsLoaded(
          requests: currentState.requests,
          submissionResult: const PrivacySubmissionResult.failure(
            errorMessage: 'Submitting...',
            submittedType: PrivacyRequestType.dataExport,
          ),
        ),
      );
    }

    final result = await _repository.submitRequest(
      const CreatePrivacyRequest(requestType: PrivacyRequestType.dataExport),
    );

    if (result.wasSuccess) {
      // Reload the list to get the updated status
      final requests = await _repository.getMyRequests();
      _cachedRequests = requests;
      emit(
        PrivacyRequestsLoaded(
          requests: requests,
          submissionResult: PrivacySubmissionResult.success(
            request: result.request,
          ),
        ),
      );
    } else {
      if (currentState is PrivacyRequestsLoaded) {
        emit(
          PrivacyRequestsLoaded(
            requests: currentState.requests,
            submissionResult: PrivacySubmissionResult.failure(
              errorMessage: result.errorMessage ?? 'Failed to submit request.',
              submittedType: PrivacyRequestType.dataExport,
            ),
          ),
        );
      } else {
        emit(
          PrivacyError(
            message:
                result.errorMessage ?? 'Failed to submit data export request.',
            lastRequests: _cachedRequests.isNotEmpty ? _cachedRequests : null,
          ),
        );
      }
    }
  }

  Future<void> _onSubmitAccountDeletionRequest(
    SubmitAccountDeletionRequest event,
    Emitter<PrivacyState> emit,
  ) async {
    final currentState = state;
    if (currentState is PrivacyRequestsLoaded) {
      emit(
        PrivacyRequestsLoaded(
          requests: currentState.requests,
          submissionResult: const PrivacySubmissionResult.failure(
            errorMessage: 'Submitting...',
            submittedType: PrivacyRequestType.accountDeletion,
          ),
        ),
      );
    }

    final result = await _repository.submitRequest(
      const CreatePrivacyRequest(
        requestType: PrivacyRequestType.accountDeletion,
      ),
    );

    if (result.wasSuccess) {
      final requests = await _repository.getMyRequests();
      _cachedRequests = requests;
      emit(
        PrivacyRequestsLoaded(
          requests: requests,
          submissionResult: PrivacySubmissionResult.success(
            request: result.request,
          ),
        ),
      );
    } else {
      if (currentState is PrivacyRequestsLoaded) {
        emit(
          PrivacyRequestsLoaded(
            requests: currentState.requests,
            submissionResult: PrivacySubmissionResult.failure(
              errorMessage: result.errorMessage ?? 'Failed to submit request.',
              submittedType: PrivacyRequestType.accountDeletion,
            ),
          ),
        );
      } else {
        emit(
          PrivacyError(
            message:
                result.errorMessage ??
                'Failed to submit account deletion request.',
            lastRequests: _cachedRequests.isNotEmpty ? _cachedRequests : null,
          ),
        );
      }
    }
  }

  Future<void> _onSubmitRoundDeletionRequest(
    SubmitRoundDeletionRequest event,
    Emitter<PrivacyState> emit,
  ) async {
    final currentState = state;
    if (currentState is PrivacyRequestsLoaded) {
      emit(
        PrivacyRequestsLoaded(
          requests: currentState.requests,
          submissionResult: const PrivacySubmissionResult.failure(
            errorMessage: 'Submitting...',
            submittedType: PrivacyRequestType.roundDeletion,
          ),
        ),
      );
    }

    final result = await _repository.submitRequest(
      CreatePrivacyRequest(
        requestType: PrivacyRequestType.roundDeletion,
        targetRoundId: event.targetRoundId,
      ),
    );

    if (result.wasSuccess) {
      final requests = await _repository.getMyRequests();
      _cachedRequests = requests;
      emit(
        PrivacyRequestsLoaded(
          requests: requests,
          submissionResult: PrivacySubmissionResult.success(
            request: result.request,
          ),
        ),
      );
    } else {
      if (currentState is PrivacyRequestsLoaded) {
        emit(
          PrivacyRequestsLoaded(
            requests: currentState.requests,
            submissionResult: PrivacySubmissionResult.failure(
              errorMessage: result.errorMessage ?? 'Failed to submit request.',
              submittedType: PrivacyRequestType.roundDeletion,
            ),
          ),
        );
      } else {
        emit(
          PrivacyError(
            message:
                result.errorMessage ??
                'Failed to submit round deletion request.',
            lastRequests: _cachedRequests.isNotEmpty ? _cachedRequests : null,
          ),
        );
      }
    }
  }

  Future<void> _onLoadRequestDetail(
    LoadRequestDetail event,
    Emitter<PrivacyState> emit,
  ) async {
    emit(const PrivacyLoading());
    try {
      final request = await _repository.getRequestById(event.requestId);
      emit(PrivacyRequestDetailLoaded(request: request));
    } catch (ex) {
      emit(
        PrivacyError(
          message: AppMessages.privacyDetailLoadFailed,
          lastRequests: _cachedRequests.isNotEmpty ? _cachedRequests : null,
        ),
      );
    }
  }

  void _onClearSubmissionResult(
    ClearSubmissionResult event,
    Emitter<PrivacyState> emit,
  ) {
    final currentState = state;
    if (currentState is PrivacyRequestsLoaded) {
      emit(currentState.copyWith(clearSubmissionResult: true));
    }
  }
}
