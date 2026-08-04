// CorrectionSubmissionBloc unit tests — VSP Mobile App
//
// Tests cover:
// - Initial state is CorrectionSubmissionInitial
// - LoadCorrectionForm emits [Loading, FormReady] with location
// - LoadCorrectionForm emits [Loading, FormReady] with null location on GPS failure
// - SubmitCorrection emits [Loading, Success] on valid submission
// - SubmitCorrection emits [Loading, Failure] on validation error
//
// Per Story 9.1 Slice 3: Submission form UI.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/presentation/correction_submission_bloc.dart';
import 'package:vsp_mobile/data/repositories/course_correction_repository.dart';
import 'package:vsp_mobile/domain/models/qualified_location.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';
import 'package:vsp_mobile/domain/services/location_service.dart';

/// Fake LocationService that returns a configurable location or throws.
class FakeLocationService implements LocationService {
  QualifiedLocation? fakeLocation;
  bool shouldThrow = false;

  @override
  Stream<QualifiedLocation> get locationStream => Stream.empty();

  @override
  QualifiedLocation? get lastLocation => fakeLocation;

  @override
  Future<QualifiedLocation> getCurrentLocation() async {
    if (shouldThrow) throw Exception('GPS unavailable');
    return fakeLocation ?? QualifiedLocation.unavailable();
  }

  @override
  void start() {}

  @override
  void stop() {}

  @override
  Future<bool> isLocationAvailable() async => !shouldThrow;

  @override
  Duration get stationaryInterval => const Duration(seconds: 30);

  @override
  Duration get activeInterval => const Duration(seconds: 5);

  @override
  void dispose() {}
}

/// In-memory fake implementation of CourseCorrectionRepository.
class FakeCourseCorrectionRepository implements CourseCorrectionRepository {
  CourseCorrection? lastSubmitted;
  final List<CourseCorrection> _corrections = [];

  @override
  Future<({CourseCorrection correction, SyncEvent syncEvent})> submitCorrection(
    CourseCorrection correction,
  ) async {
    lastSubmitted = correction;
    _corrections.add(correction);
    return (
      correction: correction,
      syncEvent: SyncEvent.forCorrection(
        correctionId: correction.id,
        correctionPayload: correction.toJson(),
      ),
    );
  }

  @override
  Future<List<CourseCorrection>> getCorrectionsByState(
    CorrectionSyncState state,
  ) async {
    return _corrections.where((c) => c.syncState == state).toList();
  }

  @override
  Future<List<CourseCorrection>> getCorrectionsForCourse(
    String courseId,
  ) async {
    return _corrections.where((c) => c.courseId == courseId).toList();
  }

  @override
  Future<CourseCorrection?> getCorrectionById(String id) async {
    try {
      return _corrections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateCorrectionSyncState(
    String id,
    CorrectionSyncState state,
  ) async {
    final idx = _corrections.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _corrections[idx] = _corrections[idx].copyWith(syncState: state);
    }
  }

  @override
  Future<void> onSyncComplete(String idempotencyKey) async {}

  @override
  Future<void> onServerStatusUpdate(
    String correctionId,
    CorrectionSyncState state,
  ) async {}
}

void main() {
  group('CorrectionSubmissionBloc', () {
    late FakeCourseCorrectionRepository fakeRepo;
    late FakeLocationService fakeLocationService;

    setUp(() {
      fakeRepo = FakeCourseCorrectionRepository();
      fakeLocationService = FakeLocationService();
    });

    test('initial state is CorrectionSubmissionInitial', () {
      final bloc = CorrectionSubmissionBloc(
        repository: fakeRepo,
        locationService: fakeLocationService,
      );
      expect(bloc.state, isA<CorrectionSubmissionInitial>());
      bloc.close();
    });

    blocTest<CorrectionSubmissionBloc, CorrectionSubmissionState>(
      'LoadCorrectionForm emits [Loading, FormReady] with location on success',
      setUp: () {
        fakeLocationService.fakeLocation = QualifiedLocation(
          latitude: 10.762622,
          longitude: 106.660020,
          accuracyMeters: 3.5,
          timestamp: DateTime.now(),
          source: LocationSource.gps,
          isStale: false,
        );
      },
      build: () => CorrectionSubmissionBloc(
        repository: fakeRepo,
        locationService: fakeLocationService,
      ),
      act: (bloc) => bloc.add(
        const LoadCorrectionForm(courseId: 'course-001', holeId: 'hole-001'),
      ),
      expect: () => [
        isA<CorrectionSubmissionLoading>(),
        isA<CorrectionFormReady>(),
      ],
    );

    blocTest<CorrectionSubmissionBloc, CorrectionSubmissionState>(
      'LoadCorrectionForm emits [Loading, FormReady] with null location on GPS failure',
      setUp: () {
        fakeLocationService.shouldThrow = true;
      },
      build: () => CorrectionSubmissionBloc(
        repository: fakeRepo,
        locationService: fakeLocationService,
      ),
      act: (bloc) => bloc.add(
        const LoadCorrectionForm(courseId: 'course-001', holeId: null),
      ),
      expect: () => [
        isA<CorrectionSubmissionLoading>(),
        isA<CorrectionFormReady>(),
      ],
    );

    blocTest<CorrectionSubmissionBloc, CorrectionSubmissionState>(
      'SubmitCorrection emits [Loading, Success] on valid submission',
      build: () => CorrectionSubmissionBloc(
        repository: fakeRepo,
        locationService: fakeLocationService,
      ),
      act: (bloc) => bloc.add(
        SubmitCorrection(
          issueType: CorrectionIssueType.pinPosition,
          note: 'Pin is off',
          courseId: 'course-001',
          holeId: 'hole-001',
          reporterLat: 10.762622,
          reporterLng: 106.660020,
          gpsAccuracy: 3.5,
        ),
      ),
      expect: () => [
        isA<CorrectionSubmissionLoading>(),
        isA<CorrectionSubmissionSuccess>(),
      ],
      verify: (_) {
        expect(fakeRepo.lastSubmitted, isNotNull);
        expect(fakeRepo.lastSubmitted!.courseId, 'course-001');
        expect(
          fakeRepo.lastSubmitted!.issueType,
          CorrectionIssueType.pinPosition,
        );
        expect(fakeRepo.lastSubmitted!.syncState, CorrectionSyncState.pending);
      },
    );

    blocTest<CorrectionSubmissionBloc, CorrectionSubmissionState>(
      'SubmitCorrection accepts empty note (optional)',
      build: () => CorrectionSubmissionBloc(
        repository: fakeRepo,
        locationService: fakeLocationService,
      ),
      act: (bloc) => bloc.add(
        SubmitCorrection(
          issueType: CorrectionIssueType.holeGeometry,
          note: '',
          courseId: 'course-001',
          holeId: null,
          reporterLat: 10.762622,
          reporterLng: 106.660020,
          gpsAccuracy: 8.0,
        ),
      ),
      expect: () => [
        isA<CorrectionSubmissionLoading>(),
        isA<CorrectionSubmissionSuccess>(),
      ],
      verify: (_) {
        expect(fakeRepo.lastSubmitted!.note, isNull);
      },
    );

    blocTest<CorrectionSubmissionBloc, CorrectionSubmissionState>(
      'SubmitCorrection emits [Loading, Failure] when courseId is empty',
      build: () => CorrectionSubmissionBloc(
        repository: fakeRepo,
        locationService: fakeLocationService,
      ),
      act: (bloc) => bloc.add(
        SubmitCorrection(
          issueType: CorrectionIssueType.pinPosition,
          note: null,
          courseId: '', // invalid
          holeId: null,
          reporterLat: 0,
          reporterLng: 0,
          gpsAccuracy: 0,
        ),
      ),
      expect: () => [
        isA<CorrectionSubmissionLoading>(),
        isA<CorrectionSubmissionFailure>(),
      ],
    );
  });
}
