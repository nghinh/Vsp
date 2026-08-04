// Profile Events — VSP Mobile App
//
// Events for ProfileBloc: load, update field, unit change, queue flush.

part of 'profile_bloc.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => const [];
}

/// Load (or reload) the profile.
class LoadProfile extends ProfileEvent {
  final bool forceReload;

  const LoadProfile({this.forceReload = false});

  @override
  List<Object?> get props => [forceReload];
}

/// Update a single field on the profile.
class UpdateProfileField extends ProfileEvent {
  /// The field being updated.
  final ProfileField field;

  /// New value (type depends on [field]).
  final dynamic value;

  const UpdateProfileField({required this.field, required this.value});

  @override
  List<Object?> get props => [field, value];
}

/// Save the current field value to the server (or queue if offline).
class SaveField extends ProfileEvent {
  final ProfileField field;

  const SaveField({required this.field});

  @override
  List<Object?> get props => [field];
}

/// Unit changed — update display unit preference.
class UnitChanged extends ProfileEvent {
  final DistanceUnit unit;

  const UnitChanged({required this.unit});

  @override
  List<Object?> get props => [unit];
}

/// Flush the offline sync queue — called on app start / reconnect.
class FlushQueue extends ProfileEvent {
  const FlushQueue();
}

/// Profile field enum — used to identify which field changed.
enum ProfileField {
  handicap,
  homeClub,
  distanceUnit,
  dominantHand,
  skillLevel,
  targetScore,
  driverDistance,
  swingSpeed,
  gender,
  birthYear,
  country,
  imageUrl,
}
