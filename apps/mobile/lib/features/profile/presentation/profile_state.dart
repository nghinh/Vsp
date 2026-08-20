// Profile States — VSP Mobile App
//
// States for ProfileBloc.

part of 'profile_bloc.dart';

// ─── States ────────────────────────────────────────────────────────────────────

/// Base state for ProfileBloc.
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no profile loaded yet.
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Loading the profile.
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// Profile loaded and ready for display.
class ProfileLoaded extends ProfileState {
  final GolferProfileDto profile;

  /// True when there are unsaved offline edits queued.
  final bool hasPendingSync;

  /// The field currently being saved (null if none).
  final ProfileField? savingField;

  /// True when the offline queue is being flushed.
  final bool isSyncing;

  const ProfileLoaded({
    required this.profile,
    this.hasPendingSync = false,
    this.savingField,
    this.isSyncing = false,
  });

  ProfileLoaded copyWith({
    GolferProfileDto? profile,
    bool? hasPendingSync,
    ProfileField? savingField,
    bool? isSyncing,
    bool clearSavingField = false,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      hasPendingSync: hasPendingSync ?? this.hasPendingSync,
      savingField: clearSavingField ? null : (savingField ?? this.savingField),
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [profile, hasPendingSync, savingField, isSyncing];
}

/// Error loading or updating profile.
class ProfileError extends ProfileState {
  final String message;

  /// The specific cause, when one is known — a message key or server text
  /// the error view shows under the generic headline. Null means the view
  /// shows the headline alone rather than repeating it.
  final String? detail;

  /// The profile before the error occurred (may be null).
  final GolferProfileDto? lastProfile;

  const ProfileError({required this.message, this.detail, this.lastProfile});

  @override
  List<Object?> get props => [message, detail, lastProfile];
}

/// The server refused the session and a refresh could not save it.
///
/// [ApiClient] has already tried the refresh token by the time a 401 reaches
/// this bloc, so this state means the session is truly over. The screen's
/// listener answers it by signing the golfer out — a "Try again" button
/// cannot help, and before this state existed it was all a golfer got.
class ProfileSessionExpired extends ProfileState {
  const ProfileSessionExpired();
}
