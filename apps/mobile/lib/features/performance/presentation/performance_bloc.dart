// PerformanceBloc — VSP Mobile App
//
// BLoC for club performance and dispersion overlay state management.
// Per Story 11.1 Slice 3.
//
// Supports:
// - Per-club performance stats
// - Bag-level performance summary
// - Dispersion overlay with layer toggles

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/performance_repository.dart';
import '../../../core/network/api_client.dart';
import 'performance_event.dart';
import 'performance_state.dart';

/// BLoC for club performance and dispersion overlay.
class PerformanceBloc extends Bloc<PerformanceEvent, PerformanceState> {
  final PerformanceRepository _repository;

  PerformanceBloc({required PerformanceRepository repository})
    : _repository = repository,
      super(const PerformanceInitial()) {
    on<LoadClubPerformance>(_onLoadClubPerformance);
    on<LoadBagPerformance>(_onLoadBagPerformance);
    on<RefreshPerformance>(_onRefreshPerformance);
    on<LoadDispersionOverlay>(_onLoadDispersionOverlay);
    on<ClearDispersionOverlay>(_onClearDispersionOverlay);
  }

  // ─── Club Performance ───────────────────────────────────────────────────────

  Future<void> _onLoadClubPerformance(
    LoadClubPerformance event,
    Emitter<PerformanceState> emit,
  ) async {
    emit(ClubPerformanceLoading(bagId: event.bagId, clubId: event.clubId));

    try {
      final stats = await _repository.getClubPerformance(
        bagId: event.bagId,
        clubId: event.clubId,
        forceReload: event.forceReload,
      );
      emit(ClubPerformanceLoaded(stats: stats));
    } on VspApiException catch (ex) {
      emit(
        PerformanceError(
          message: ex.message,
          bagId: event.bagId,
          clubId: event.clubId,
        ),
      );
    } catch (ex) {
      emit(
        PerformanceError(
          message: 'Failed to load club performance. Please try again.',
          bagId: event.bagId,
          clubId: event.clubId,
        ),
      );
    }
  }

  // ─── Bag Performance ────────────────────────────────────────────────────────

  Future<void> _onLoadBagPerformance(
    LoadBagPerformance event,
    Emitter<PerformanceState> emit,
  ) async {
    emit(BagPerformanceLoading(bagId: event.bagId));

    try {
      final performance = await _repository.getBagPerformance(
        bagId: event.bagId,
        forceReload: event.forceReload,
      );
      emit(BagPerformanceLoaded(performance: performance));
    } on VspApiException catch (ex) {
      emit(PerformanceError(message: ex.message, bagId: event.bagId));
    } catch (ex) {
      emit(
        PerformanceError(
          message: 'Failed to load bag performance. Please try again.',
          bagId: event.bagId,
        ),
      );
    }
  }

  // ─── Refresh ────────────────────────────────────────────────────────────────

  Future<void> _onRefreshPerformance(
    RefreshPerformance event,
    Emitter<PerformanceState> emit,
  ) async {
    final currentState = state;

    if (currentState is ClubPerformanceLoaded) {
      add(
        LoadClubPerformance(
          bagId: currentState.stats.bagId,
          clubId: currentState.stats.clubId,
          forceReload: true,
        ),
      );
    } else if (currentState is BagPerformanceLoaded) {
      add(
        LoadBagPerformance(
          bagId: currentState.performance.bagId,
          forceReload: true,
        ),
      );
    }
  }

  // ─── Dispersion Overlay ─────────────────────────────────────────────────────

  Future<void> _onLoadDispersionOverlay(
    LoadDispersionOverlay event,
    Emitter<PerformanceState> emit,
  ) async {
    emit(
      DispersionOverlayLoading(
        bagId: event.bagId,
        clubId: event.clubId,
        holeId: event.holeId,
        layoutId: event.layoutId,
      ),
    );

    try {
      final overlay = await _repository.getDispersionOverlay(
        bagId: event.bagId,
        clubId: event.clubId,
        holeId: event.holeId,
        layoutId: event.layoutId,
        forceReload: event.forceReload,
      );
      emit(DispersionOverlayLoaded(overlay: overlay));
    } on VspApiException catch (ex) {
      emit(
        DispersionOverlayError(
          message: ex.message,
          bagId: event.bagId,
          clubId: event.clubId,
          holeId: event.holeId,
          layoutId: event.layoutId,
        ),
      );
    } catch (ex) {
      emit(
        DispersionOverlayError(
          message: 'Failed to load dispersion overlay. Please try again.',
          bagId: event.bagId,
          clubId: event.clubId,
          holeId: event.holeId,
          layoutId: event.layoutId,
        ),
      );
    }
  }

  Future<void> _onClearDispersionOverlay(
    ClearDispersionOverlay event,
    Emitter<PerformanceState> emit,
  ) async {
    emit(const PerformanceInitial());
  }
}
