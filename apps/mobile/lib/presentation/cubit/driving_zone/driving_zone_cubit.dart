// Driving Zone Cubit — VSP Mobile App
//
// Manages the Driving Zone analytics screen state.
// Handles filter changes, data fetching, and loading/error/empty states.
//
// Per Story 11.2: Deliver Driving Zone and Round Analytics.
// AC1: Driving Zone supports time, club, tee, and wind filters.

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/driving_zone_filter.dart';
import '../../../domain/models/driving_zone_statistics.dart';
import '../../../domain/models/incomplete_data_warning.dart';
import '../../../data/repositories/shot_repository_impl.dart';
import '../../../domain/repositories/shot_repository.dart';
import 'driving_zone_state.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

/// Cubit for managing the Driving Zone analytics screen.
class DrivingZoneCubit extends Cubit<DrivingZoneState> {
  final ShotRepository _shotRepository;

  /// Current active filter.
  DrivingZoneFilter? _currentFilter;

  DrivingZoneCubit({ShotRepository? shotRepository})
    : _shotRepository = shotRepository ?? ShotRepositoryImpl(),
      super(const DrivingZoneInitial());

  /// Current active filter (null until first load).
  DrivingZoneFilter? get currentFilter => _currentFilter;

  /// Load driving zone statistics with the given [filter].
  ///
  /// Per AC1: filter controls are wired to cubit and re-fetch zone data.
  Future<void> loadWithFilter(DrivingZoneFilter filter) async {
    _currentFilter = filter;
    emit(const DrivingZoneLoading());

    try {
      final stats = await _shotRepository.getDrivingZoneStats(filter);

      if (stats.holeStats.isEmpty ||
          stats.totalShots < filter.minimumShotCount) {
        final warning =
            stats.isSampleInsufficient ||
                stats.totalShots < filter.minimumShotCount
            ? IncompleteDataWarning.forTotalShots(
                requiredMinimum: filter.minimumShotCount,
                actualCount: stats.totalShots,
                generatedAt: DateTime.now(),
              )
            : null;

        emit(DrivingZoneEmpty(filter: filter, warning: warning));
        return;
      }

      emit(DrivingZoneLoaded(statistics: stats, activeFilter: filter));
    } catch (e) {
      emit(
        DrivingZoneError(
          message: AppMessages.drivingZoneLoadFailed,
          lastFilter: filter,
        ),
      );
    }
  }

  /// Update the time range filter and reload.
  Future<void> updateTimeRange(TimeRange timeRange) async {
    final current = _currentFilter;
    if (current == null) return;
    await loadWithFilter(current.copyWith(timeRange: timeRange));
  }

  /// Update the club filter and reload.
  Future<void> updateClubs(List<String> clubIds) async {
    final current = _currentFilter;
    if (current == null) return;
    await loadWithFilter(current.copyWith(clubIds: clubIds));
  }

  /// Update the tee set filter and reload.
  Future<void> updateTeeSet(String? teeSetId) async {
    final current = _currentFilter;
    if (current == null) return;
    await loadWithFilter(
      current.copyWith(teeSetId: teeSetId, clearTeeSetId: teeSetId == null),
    );
  }

  /// Update the wind condition filter and reload.
  Future<void> updateWindCondition(WindCondition? windCondition) async {
    final current = _currentFilter;
    if (current == null) return;
    await loadWithFilter(
      current.copyWith(
        windCondition: windCondition,
        clearWindCondition: windCondition == null,
      ),
    );
  }

  /// Clear all filters and reload with default.
  Future<void> clearFilters() async {
    final current = _currentFilter;
    if (current == null) return;
    await loadWithFilter(
      current.copyWith(
        timeRange: TimeRange.allTime(),
        clubIds: [],
        clearTeeSetId: true,
        clearWindCondition: true,
      ),
    );
  }

  /// Retry the last failed request.
  Future<void> retry() async {
    final lastFilter = _currentFilter;
    if (lastFilter == null) return;
    await loadWithFilter(lastFilter);
  }
}
