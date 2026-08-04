// Tournament TournamentStatus enum — VSP Mobile App
//
// Per Story 12.1 AC.
//
// Story 12.1 Slice F

/// Tournament lifecycle status.
enum TournamentStatus {
  /// Tournament is being configured — not yet open for registration.
  draft,

  /// Registration is open for players.
  registrationOpen,

  /// Tournament is in progress (round(s) being played).
  inProgress,

  /// Tournament has concluded — results finalized.
  completed,

  /// Tournament was cancelled.
  cancelled,
}

extension TournamentStatusExtension on TournamentStatus {
  /// Display label for UI.
  String get label {
    switch (this) {
      case TournamentStatus.draft:
        return 'Draft';
      case TournamentStatus.registrationOpen:
        return 'Registration Open';
      case TournamentStatus.inProgress:
        return 'In Progress';
      case TournamentStatus.completed:
        return 'Completed';
      case TournamentStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Whether the tournament can be modified in this status.
  bool get isModifiable =>
      this == TournamentStatus.draft ||
      this == TournamentStatus.registrationOpen;

  /// Whether registration is currently accepted.
  bool get acceptsRegistration => this == TournamentStatus.registrationOpen;

  /// Whether the tournament is active (in progress).
  bool get isActive => this == TournamentStatus.inProgress;

  /// Parse from API string value.
  static TournamentStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DRAFT':
        return TournamentStatus.draft;
      case 'REGISTRATION_OPEN':
        return TournamentStatus.registrationOpen;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return TournamentStatus.inProgress;
      case 'COMPLETED':
        return TournamentStatus.completed;
      case 'CANCELLED':
      case 'CANCELED':
        return TournamentStatus.cancelled;
      default:
        throw ArgumentError('Unknown TournamentStatus: $value');
    }
  }
}
