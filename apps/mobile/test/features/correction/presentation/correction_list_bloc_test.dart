// CorrectionListBloc unit tests — VSP Mobile App
//
// Tests cover:
// - Initial state is CorrectionListInitial
// - LoadCorrections emits [Loading, Loaded] with corrections
// - LoadCorrections emits [Loading, Empty] when no corrections exist
// - LoadCorrections emits [Loading, Error] on repository failure
// - RefreshCorrections re-loads with last courseId
//
// Per Story 9.1 Slice 4: My corrections list UI.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:vsp_mobile/features/correction/domain/course_correction.dart';
import 'package:vsp_mobile/features/correction/presentation/correction_list_bloc.dart';
import 'package:vsp_mobile/data/repositories/course_correction_repository.dart';
import 'package:vsp_mobile/domain/models/sync_event.dart';

/// In-memory fake implementation of CourseCorrectionRepository.
class FakeCourseCorrectionRepository implements CourseCorrectionRepository {
  final Map<CorrectionSyncState, List<CourseCorrection>> _correctionsByState =
      {};
  final Map<String, List<CourseCorrection>> _correctionsByCourse = {};
  bool shouldThrow = false;

  void addCorrection(CourseCorrection c) {
    _correctionsByState.putIfAbsent(c.syncState, () => []).add(c);
    _correctionsByCourse.putIfAbsent(c.courseId, () => []).add(c);
  }

  int countForCourse(String courseId) =>
      _correctionsByCourse[courseId]?.length ?? 0;

  @override
  Future<({CourseCorrection correction, SyncEvent syncEvent})> submitCorrection(
    CourseCorrection correction,
  ) async {
    addCorrection(correction);
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
    if (shouldThrow) throw Exception('DB error');
    return List.from(_correctionsByState[state] ?? []);
  }

  @override
  Future<List<CourseCorrection>> getCorrectionsForCourse(
    String courseId,
  ) async {
    if (shouldThrow) throw Exception('DB error');
    return List.from(_correctionsByCourse[courseId] ?? []);
  }

  @override
  Future<CourseCorrection?> getCorrectionById(String id) async {
    for (final list in [
      ..._correctionsByState.values,
      ..._correctionsByCourse.values,
    ]) {
      try {
        return list.firstWhere((c) => c.id == id);
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<void> updateCorrectionSyncState(
    String id,
    CorrectionSyncState state,
  ) async {}

  @override
  Future<void> onSyncComplete(String idempotencyKey) async {}

  @override
  Future<void> onServerStatusUpdate(
    String correctionId,
    CorrectionSyncState state,
  ) async {}
}

void main() {
  group('CorrectionListBloc', () {
    late FakeCourseCorrectionRepository fakeRepo;
    final uuid = const Uuid();
    final now = DateTime.now().toUtc();

    CourseCorrection makeCorrection({
      String id = 'corr-001',
      String courseId = 'course-001',
      CorrectionSyncState state = CorrectionSyncState.pending,
      CorrectionIssueType issueType = CorrectionIssueType.pinPosition,
    }) {
      return CourseCorrection(
        id: id,
        courseId: courseId,
        issueType: issueType,
        reporterLat: 10.762622,
        reporterLng: 106.660020,
        gpsAccuracy: 3.5,
        submittedAt: now,
        syncState: state,
        idempotencyKey: uuid.v4(),
      );
    }

    setUp(() {
      fakeRepo = FakeCourseCorrectionRepository();
    });

    test('initial state is CorrectionListInitial', () {
      final bloc = CorrectionListBloc(repository: fakeRepo);
      expect(bloc.state, isA<CorrectionListInitial>());
      bloc.close();
    });

    blocTest<CorrectionListBloc, CorrectionListState>(
      'LoadCorrections emits [Loading, Loaded] when corrections exist for course',
      setUp: () {
        fakeRepo.addCorrection(
          makeCorrection(
            id: 'corr-001',
            courseId: 'course-001',
            state: CorrectionSyncState.pending,
          ),
        );
        fakeRepo.addCorrection(
          makeCorrection(
            id: 'corr-002',
            courseId: 'course-001',
            state: CorrectionSyncState.submitted,
          ),
        );
      },
      build: () => CorrectionListBloc(repository: fakeRepo),
      act: (bloc) => bloc.add(const LoadCorrections(courseId: 'course-001')),
      expect: () => [isA<CorrectionListLoading>(), isA<CorrectionListLoaded>()],
      verify: (_) async {
        expect(
          await fakeRepo.getCorrectionsForCourse('course-001'),
          hasLength(2),
        );
      },
    );

    blocTest<CorrectionListBloc, CorrectionListState>(
      'LoadCorrections emits [Loading, Empty] when no corrections for course',
      build: () => CorrectionListBloc(repository: fakeRepo),
      act: (bloc) => bloc.add(const LoadCorrections(courseId: 'course-empty')),
      expect: () => [isA<CorrectionListLoading>(), isA<CorrectionListEmpty>()],
    );

    blocTest<CorrectionListBloc, CorrectionListState>(
      'LoadCorrections with null courseId loads all states',
      setUp: () {
        fakeRepo.addCorrection(
          makeCorrection(
            id: 'corr-010',
            courseId: 'course-a',
            state: CorrectionSyncState.accepted,
          ),
        );
        fakeRepo.addCorrection(
          makeCorrection(
            id: 'corr-011',
            courseId: 'course-b',
            state: CorrectionSyncState.rejected,
          ),
        );
        fakeRepo.addCorrection(
          makeCorrection(
            id: 'corr-012',
            courseId: 'course-c',
            state: CorrectionSyncState.pending,
          ),
        );
      },
      build: () => CorrectionListBloc(repository: fakeRepo),
      act: (bloc) => bloc.add(const LoadCorrections(courseId: null)),
      expect: () => [isA<CorrectionListLoading>(), isA<CorrectionListLoaded>()],
      verify: (_) async {
        final all = [
          ...await fakeRepo.getCorrectionsByState(CorrectionSyncState.pending),
          ...await fakeRepo.getCorrectionsByState(
            CorrectionSyncState.submitted,
          ),
          ...await fakeRepo.getCorrectionsByState(CorrectionSyncState.accepted),
          ...await fakeRepo.getCorrectionsByState(CorrectionSyncState.rejected),
        ];
        expect(all.length, 3);
      },
    );

    blocTest<CorrectionListBloc, CorrectionListState>(
      'LoadCorrections emits [Loading, Error] on repository failure',
      setUp: () {
        fakeRepo.shouldThrow = true;
      },
      build: () => CorrectionListBloc(repository: fakeRepo),
      act: (bloc) => bloc.add(const LoadCorrections(courseId: 'course-001')),
      expect: () => [isA<CorrectionListLoading>(), isA<CorrectionListError>()],
    );

    blocTest<CorrectionListBloc, CorrectionListState>(
      'RefreshCorrections re-loads with last courseId',
      setUp: () {
        fakeRepo.addCorrection(
          makeCorrection(
            id: 'corr-020',
            courseId: 'course-refresh',
            state: CorrectionSyncState.pending,
          ),
        );
        fakeRepo.shouldThrow = false;
      },
      build: () => CorrectionListBloc(repository: fakeRepo),
      act: (bloc) async {
        bloc.add(const LoadCorrections(courseId: 'course-refresh'));
        await bloc.stream.firstWhere((state) => state is CorrectionListLoaded);
        bloc.add(const RefreshCorrections());
      },
      skip: 2, // skip Loading + Loaded from initial LoadCorrections
      expect: () => [isA<CorrectionListLoading>(), isA<CorrectionListLoaded>()],
    );
  });
}
