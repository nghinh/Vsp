// Performance States — VSP Mobile App
//
// States for club performance and dispersion overlay BLoC.
// Per Story 11.1 Slice 3.

import 'package:equatable/equatable.dart';

import '../../../domain/models/performance/club_performance_stats.dart';
import '../../../domain/models/performance/dispersion_overlay.dart';

// ─── Performance States ───────────────────────────────────────────────────────

abstract class PerformanceState extends Equatable {
  const PerformanceState();

  @override
  List<Object?> get props => [];
}

/// Initial state.
class PerformanceInitial extends PerformanceState {
  const PerformanceInitial();
}

/// Loading club performance.
class ClubPerformanceLoading extends PerformanceState {
  final int bagId;
  final int clubId;

  const ClubPerformanceLoading({required this.bagId, required this.clubId});

  @override
  List<Object?> get props => [bagId, clubId];
}

/// Loaded club performance data.
class ClubPerformanceLoaded extends PerformanceState {
  final ClubPerformanceStats stats;
  final bool isFromCache;

  const ClubPerformanceLoaded({
    required this.stats,
    this.isFromCache = false,
  });

  ClubPerformanceLoaded copyWith({
    ClubPerformanceStats? stats,
    bool? isFromCache,
  }) {
    return ClubPerformanceLoaded(
      stats: stats ?? this.stats,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  @override
  List<Object?> get props => [stats, isFromCache];
}

/// Loading bag performance.
class BagPerformanceLoading extends PerformanceState {
  final int bagId;

  const BagPerformanceLoading({required this.bagId});

  @override
  List<Object?> get props => [bagId];
}

/// Loaded bag performance data.
class BagPerformanceLoaded extends PerformanceState {
  final BagPerformance performance;
  final bool isFromCache;

  const BagPerformanceLoaded({
    required this.performance,
    this.isFromCache = false,
  });

  @override
  List<Object?> get props => [performance, isFromCache];
}

/// Performance error state.
class PerformanceError extends PerformanceState {
  final String message;
  final int? bagId;
  final int? clubId;
  final ClubPerformanceStats? lastStats;
  final BagPerformance? lastPerformance;

  const PerformanceError({
    required this.message,
    this.bagId,
    this.clubId,
    this.lastStats,
    this.lastPerformance,
  });

  @override
  List<Object?> get props => [
    message,
    bagId,
    clubId,
    lastStats,
    lastPerformance,
  ];
}

// ─── Dispersion Overlay States ────────────────────────────────────────────────

/// Loading dispersion overlay.
class DispersionOverlayLoading extends PerformanceState {
  final int bagId;
  final int clubId;
  final int holeId;
  final int layoutId;

  const DispersionOverlayLoading({
    required this.bagId,
    required this.clubId,
    required this.holeId,
    required this.layoutId,
  });

  @override
  List<Object?> get props => [bagId, clubId, holeId, layoutId];
}

/// Loaded dispersion overlay data.
class DispersionOverlayLoaded extends PerformanceState {
  final DispersionOverlay overlay;
  final bool isFromCache;

  /// Whether hazard layer is visible.
  final bool showHazards;

  /// Whether scatter layer is visible.
  final bool showScatter;

  const DispersionOverlayLoaded({
    required this.overlay,
    this.isFromCache = false,
    this.showHazards = true,
    this.showScatter = true,
  });

  DispersionOverlayLoaded copyWith({
    DispersionOverlay? overlay,
    bool? isFromCache,
    bool? showHazards,
    bool? showScatter,
  }) {
    return DispersionOverlayLoaded(
      overlay: overlay ?? this.overlay,
      isFromCache: isFromCache ?? this.isFromCache,
      showHazards: showHazards ?? this.showHazards,
      showScatter: showScatter ?? this.showScatter,
    );
  }

  @override
  List<Object?> get props => [overlay, isFromCache, showHazards, showScatter];
}

/// Dispersion overlay error state.
class DispersionOverlayError extends PerformanceState {
  final String message;
  final int bagId;
  final int clubId;
  final int holeId;
  final int layoutId;
  final DispersionOverlay? lastOverlay;

  const DispersionOverlayError({
    required this.message,
    required this.bagId,
    required this.clubId,
    required this.holeId,
    required this.layoutId,
    this.lastOverlay,
  });

  @override
  List<Object?> get props => [
    message,
    bagId,
    clubId,
    holeId,
    layoutId,
    lastOverlay,
  ];
}
