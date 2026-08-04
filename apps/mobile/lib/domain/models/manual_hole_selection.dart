// Manual Hole Selection Model — VSP Mobile App
//
// Audit log entry for user-initiated hole selection overrides.
// Appended to local SQLite table `hole_selection_log` for quality
// improvement and backend sync (story 6.2, architecture §2.4).
//
// Story 6.2 — Wave A: Interface & Model Definitions

import 'package:equatable/equatable.dart';

import 'qualified_location.dart';

/// Reason for a manual hole selection.
enum ManualSelectionReason {
  /// User explicitly chose a hole (e.g., from hole picker UI).
  userChoice,

  /// User overrode an incorrect automatic detection.
  override,

  /// User corrected a previously wrong manual selection.
  correction,

  /// App prompted user to select due to low confidence.
  promptedByLowConfidence,

  /// Hole selected during round setup or resume.
  roundSetup,
}

/// Audit record of a user-initiated hole selection.
///
/// Append-only: never mutated after creation.
/// Synced to backend when online for quality improvement (PRD §8.5).
class ManualHoleSelection extends Equatable {
  /// If a detection was attempted before this manual selection,
  /// the ID of the hole that was detected (may be null).
  final String? detectedHoleId;

  /// The hole ID the user actually selected.
  final String selectedHoleId;

  /// Why the user made this selection.
  final ManualSelectionReason reason;

  /// Detection confidence immediately before manual selection.
  /// null if no detection was attempted.
  final double? confidenceBefore;

  /// Location at time of manual selection.
  final QualifiedLocation locationAtSelection;

  /// When the user made this selection.
  final DateTime selectedAt;

  /// Unique ID for this selection record.
  final String id;

  /// Round ID this selection belongs to.
  final String roundId;

  /// Sync status.
  final ManualHoleSelectionSyncStatus syncStatus;

  const ManualHoleSelection({
    required this.id,
    required this.roundId,
    this.detectedHoleId,
    required this.selectedHoleId,
    required this.reason,
    this.confidenceBefore,
    required this.locationAtSelection,
    required this.selectedAt,
    this.syncStatus = ManualHoleSelectionSyncStatus.local,
  });

  /// True if user overrode an incorrect detection.
  bool get wasOverride =>
      reason == ManualSelectionReason.override ||
      reason == ManualSelectionReason.correction;

  /// True if this selection was prompted by low confidence.
  bool get wasPrompted =>
      reason == ManualSelectionReason.promptedByLowConfidence;

  /// Human-readable reason label.
  String get reasonLabel {
    switch (reason) {
      case ManualSelectionReason.userChoice:
        return 'User chose hole manually';
      case ManualSelectionReason.override:
        return 'Override — corrected wrong detection';
      case ManualSelectionReason.correction:
        return 'Correction — fixed previous selection';
      case ManualSelectionReason.promptedByLowConfidence:
        return 'Prompted — low confidence detection';
      case ManualSelectionReason.roundSetup:
        return 'Round setup or resume';
    }
  }

  /// Convert to a Map for SQLite persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round_id': roundId,
      'detected_hole_id': detectedHoleId,
      'selected_hole_id': selectedHoleId,
      'reason': reason.name,
      'confidence_before': confidenceBefore,
      'latitude': locationAtSelection.latitude,
      'longitude': locationAtSelection.longitude,
      'accuracy_meters': locationAtSelection.accuracyMeters,
      'heading': locationAtSelection.heading,
      'location_source': locationAtSelection.source.name,
      'location_timestamp': locationAtSelection.timestamp
          .toUtc()
          .toIso8601String(),
      'selected_at': selectedAt.toUtc().toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  /// Reconstruct from a SQLite row.
  factory ManualHoleSelection.fromMap(Map<String, dynamic> map) {
    return ManualHoleSelection(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      detectedHoleId: map['detected_hole_id'] as String?,
      selectedHoleId: map['selected_hole_id'] as String,
      reason: ManualSelectionReason.values.firstWhere(
        (r) => r.name == map['reason'],
        orElse: () => ManualSelectionReason.userChoice,
      ),
      confidenceBefore: map['confidence_before'] as double?,
      locationAtSelection: QualifiedLocation(
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        accuracyMeters: map['accuracy_meters'] as double?,
        heading: map['heading'] as double?,
        source: LocationSource.values.firstWhere(
          (s) => s.name == map['location_source'],
          orElse: () => LocationSource.gps,
        ),
        timestamp: DateTime.parse(map['location_timestamp'] as String),
        isStale: false,
      ),
      selectedAt: DateTime.parse(map['selected_at'] as String),
      syncStatus: ManualHoleSelectionSyncStatus.fromString(
        map['sync_status'] as String? ?? 'local',
      ),
    );
  }

  ManualHoleSelection copyWith({
    String? id,
    String? roundId,
    String? detectedHoleId,
    String? selectedHoleId,
    ManualSelectionReason? reason,
    double? confidenceBefore,
    QualifiedLocation? locationAtSelection,
    DateTime? selectedAt,
    ManualHoleSelectionSyncStatus? syncStatus,
  }) {
    return ManualHoleSelection(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      detectedHoleId: detectedHoleId ?? this.detectedHoleId,
      selectedHoleId: selectedHoleId ?? this.selectedHoleId,
      reason: reason ?? this.reason,
      confidenceBefore: confidenceBefore ?? this.confidenceBefore,
      locationAtSelection: locationAtSelection ?? this.locationAtSelection,
      selectedAt: selectedAt ?? this.selectedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  List<Object?> get props => [
    id,
    roundId,
    detectedHoleId,
    selectedHoleId,
    reason,
    confidenceBefore,
    locationAtSelection,
    selectedAt,
    syncStatus,
  ];
}

/// Sync status for ManualHoleSelection records.
enum ManualHoleSelectionSyncStatus {
  /// Record exists only in local SQLite.
  local,

  /// Record queued for sync to backend.
  pending,

  /// Record synced to backend successfully.
  synced,

  /// Sync failed; will retry.
  failed;

  static ManualHoleSelectionSyncStatus fromString(String value) {
    return ManualHoleSelectionSyncStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ManualHoleSelectionSyncStatus.local,
    );
  }
}
