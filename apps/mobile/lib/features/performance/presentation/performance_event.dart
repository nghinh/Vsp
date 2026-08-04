// Performance Events — VSP Mobile App
//
// Events for club performance and dispersion overlay BLoC.
// Per Story 11.1 Slice 3.

import 'package:equatable/equatable.dart';

// ─── Club Performance Events ─────────────────────────────────────────────────

abstract class PerformanceEvent extends Equatable {
  const PerformanceEvent();

  @override
  List<Object?> get props => [];
}

/// Load performance for a specific club.
class LoadClubPerformance extends PerformanceEvent {
  final int bagId;
  final int clubId;
  final bool forceReload;

  const LoadClubPerformance({
    required this.bagId,
    required this.clubId,
    this.forceReload = false,
  });

  @override
  List<Object?> get props => [bagId, clubId, forceReload];
}

/// Load performance for all clubs in a bag.
class LoadBagPerformance extends PerformanceEvent {
  final int bagId;
  final bool forceReload;

  const LoadBagPerformance({required this.bagId, this.forceReload = false});

  @override
  List<Object?> get props => [bagId, forceReload];
}

/// Refresh performance data.
class RefreshPerformance extends PerformanceEvent {
  const RefreshPerformance();
}

// ─── Dispersion Overlay Events ───────────────────────────────────────────────

/// Load dispersion overlay for a club on a specific hole.
class LoadDispersionOverlay extends PerformanceEvent {
  final int bagId;
  final int clubId;
  final int holeId;
  final int layoutId;
  final bool forceReload;

  const LoadDispersionOverlay({
    required this.bagId,
    required this.clubId,
    required this.holeId,
    required this.layoutId,
    this.forceReload = false,
  });

  @override
  List<Object?> get props => [bagId, clubId, holeId, layoutId, forceReload];
}

/// Clear dispersion overlay from state.
class ClearDispersionOverlay extends PerformanceEvent {
  const ClearDispersionOverlay();
}
