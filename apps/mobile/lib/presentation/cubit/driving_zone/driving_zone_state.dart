// Driving Zone State — VSP Mobile App
//
// State classes for the Driving Zone analytics screen.
// Per Story 11.2: Deliver Driving Zone and Round Analytics.

import 'package:equatable/equatable.dart';

import '../../../domain/models/driving_zone_filter.dart';
import '../../../domain/models/driving_zone_statistics.dart';
import '../../../domain/models/incomplete_data_warning.dart';

/// Screen state for the Driving Zone analytics view.
sealed class DrivingZoneState extends Equatable {
  const DrivingZoneState();
}

// ─── Concrete States ───────────────────────────────────────────────────────────

/// Initial state before any data is loaded.
class DrivingZoneInitial extends DrivingZoneState {
  const DrivingZoneInitial();

  @override
  List<Object?> get props => [];
}

/// Loading state while fetching zone statistics.
class DrivingZoneLoading extends DrivingZoneState {
  const DrivingZoneLoading();

  @override
  List<Object?> get props => [];
}

/// No shots found for the current filter.
class DrivingZoneEmpty extends DrivingZoneState {
  final DrivingZoneFilter filter;
  final IncompleteDataWarning? warning;

  const DrivingZoneEmpty({required this.filter, this.warning});

  @override
  List<Object?> get props => [filter, warning];
}

/// Successfully loaded zone statistics.
class DrivingZoneLoaded extends DrivingZoneState {
  final DrivingZoneStatistics statistics;
  final DrivingZoneFilter activeFilter;

  const DrivingZoneLoaded({
    required this.statistics,
    required this.activeFilter,
  });

  @override
  List<Object?> get props => [statistics, activeFilter];
}

/// Error state when loading fails.
class DrivingZoneError extends DrivingZoneState {
  final String message;
  final DrivingZoneFilter? lastFilter;

  const DrivingZoneError({required this.message, this.lastFilter});

  @override
  List<Object?> get props => [message, lastFilter];
}
