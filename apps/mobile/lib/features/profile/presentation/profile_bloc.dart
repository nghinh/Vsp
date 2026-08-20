// Profile BLoC — VSP Mobile App
//
// State management for the profile screen.
//
// Events: LoadProfile, UpdateProfileField, SaveField, UnitChanged, FlushQueue
// States: ProfileInitial, ProfileLoading, ProfileLoaded, ProfileError
//
// AC-1: All profile fields supported.
// AC-2: Unit picker triggers immediate display conversion (no server round-trip).
// AC-3: Offline sync feedback — "Saved offline" / "Synced" indicators.

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profile_dto.dart';
import '../data/profile_repository.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
part 'profile_event.dart';
part 'profile_state.dart';

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _profileRepository;

  /// The current editable values — kept in sync with UI controllers.
  GolferProfileDto? _draft;

  ProfileBloc({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(const ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfileField>(_onUpdateProfileField);
    on<SaveField>(_onSaveField);
    on<UnitChanged>(_onUnitChanged);
    on<FlushQueue>(_onFlushQueue);
  }

  GolferProfileDto? get draft => _draft;

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final profile = event.forceReload
          ? await _profileRepository.getProfile()
          : (_profileRepository.getCachedProfile() ??
                await _profileRepository.getProfile());
      _draft = profile;
      final hasPending = await _profileRepository.hasPending();
      emit(ProfileLoaded(profile: profile, hasPendingSync: hasPending));
    } on VspApiException catch (ex) {
      debugPrint('ProfileBloc.load failed: $ex');
      if (ex.statusCode == 401) {
        // ApiClient has already spent the refresh token on this 401. What is
        // left is a dead session, and "Try again" retries it into the same
        // wall — the golfer stared at that button until they guessed at
        // signing out themselves (2026-08-20, on a phone, at 07:45).
        emit(const ProfileSessionExpired());
      } else {
        emit(
          ProfileError(
            message: AppMessages.profileLoadFailed,
            detail: ex.message,
          ),
        );
      }
    } catch (ex) {
      // The cause used to vanish here. Every failure — the request, the JSON,
      // the local sync queue — produced the same sentence and the same "Try
      // again", and nothing anywhere recorded which one had happened.
      debugPrint('ProfileBloc.load failed: $ex');
      emit(
        ProfileError(
          message: AppMessages.profileLoadFailed,
          detail: ex.toString(),
        ),
      );
    }
  }

  void _onUpdateProfileField(
    UpdateProfileField event,
    Emitter<ProfileState> emit,
  ) {
    final draft = _draft;
    if (draft == null) return;

    switch (event.field) {
      case ProfileField.handicap:
        _draft = draft.copyWith(handicap: event.value as double?);
        break;
      case ProfileField.homeClub:
        _draft = draft.copyWith(homeClub: event.value as String?);
        break;
      case ProfileField.distanceUnit:
        _draft = draft.copyWith(distanceUnit: event.value as DistanceUnit);
        break;
      case ProfileField.dominantHand:
        _draft = draft.copyWith(dominantHand: event.value as DominantHand);
        break;
      case ProfileField.skillLevel:
        _draft = draft.copyWith(skillLevel: event.value as SkillLevel);
        break;
      case ProfileField.targetScore:
        _draft = draft.copyWith(targetScore: event.value as int?);
        break;
      case ProfileField.driverDistance:
        _draft = draft.copyWith(
          driverDistance: (event.value as num?)?.toDouble(),
        );
        break;
      case ProfileField.swingSpeed:
        _draft = draft.copyWith(swingSpeed: (event.value as num?)?.toDouble());
        break;
      case ProfileField.gender:
        _draft = draft.copyWith(gender: event.value as Gender);
        break;
      case ProfileField.birthYear:
        _draft = draft.copyWith(birthYear: event.value as int?);
        break;
      case ProfileField.country:
        _draft = draft.copyWith(country: event.value as String?);
        break;
      case ProfileField.imageUrl:
        _draft = draft.copyWith(imageUrl: event.value as String?);
        break;
    }

    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(currentState.copyWith(profile: _draft));
    }
  }

  Future<void> _onSaveField(SaveField event, Emitter<ProfileState> emit) async {
    final draft = _draft;
    if (draft == null) return;

    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    // Emit saving state for this field
    emit(currentState.copyWith(savingField: event.field));

    // Build partial update request for this field
    final request = _buildRequest(event.field, draft);

    try {
      final result = await _profileRepository.queueProfileUpdate(request);
      _draft = result.serverProfile ?? draft;
      emit(
        currentState.copyWith(
          profile: _draft,
          hasPendingSync: result.queuedOffline,
          clearSavingField: true,
        ),
      );
    } on VspApiException catch (ex) {
      if (ex.statusCode == 401) {
        emit(const ProfileSessionExpired());
        return;
      }
      emit(
        ProfileError(
          message: AppMessages.profileSaveFailed,
          detail: ex.message,
          lastProfile: draft,
        ),
      );
    } catch (_) {
      emit(
        ProfileError(
          message: AppMessages.profileSaveFailed,
          lastProfile: draft,
        ),
      );
    }
  }

  /// Unit change is a special case — it only updates the local display
  /// preference without needing a server round-trip.
  Future<void> _onUnitChanged(
    UnitChanged event,
    Emitter<ProfileState> emit,
  ) async {
    final draft = _draft;
    if (draft == null) return;

    _draft = draft.copyWith(distanceUnit: event.unit);

    final currentState = state;
    if (currentState is ProfileLoaded) {
      emit(currentState.copyWith(profile: _draft));
    }

    // Persist unit preference immediately
    final request = UpdateProfileRequest(distanceUnit: event.unit.value);
    final result = await _profileRepository.queueProfileUpdate(request);

    if (result.queuedOffline) {
      if (currentState is ProfileLoaded) {
        emit(currentState.copyWith(profile: _draft, hasPendingSync: true));
      }
    } else if (result.serverProfile != null) {
      _draft = result.serverProfile;
      if (currentState is ProfileLoaded) {
        emit(currentState.copyWith(profile: _draft, hasPendingSync: false));
      }
    }
  }

  Future<void> _onFlushQueue(
    FlushQueue event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    emit(currentState.copyWith(isSyncing: true));

    try {
      await _profileRepository.flushQueue();
      final hasPending = await _profileRepository.hasPending();
      emit(currentState.copyWith(hasPendingSync: hasPending, isSyncing: false));
    } catch (_) {
      emit(currentState.copyWith(isSyncing: false));
    }
  }

  /// Build a partial [UpdateProfileRequest] for a single changed [field].
  UpdateProfileRequest _buildRequest(
    ProfileField field,
    GolferProfileDto draft,
  ) {
    switch (field) {
      case ProfileField.handicap:
        return UpdateProfileRequest(handicap: draft.handicap);
      case ProfileField.homeClub:
        return UpdateProfileRequest(homeClub: draft.homeClub);
      case ProfileField.distanceUnit:
        return UpdateProfileRequest(distanceUnit: draft.distanceUnit.value);
      case ProfileField.dominantHand:
        return UpdateProfileRequest(dominantHand: draft.dominantHand.value);
      case ProfileField.skillLevel:
        return UpdateProfileRequest(skillLevel: draft.skillLevel.value);
      case ProfileField.targetScore:
        return UpdateProfileRequest(targetScore: draft.targetScore);
      case ProfileField.driverDistance:
        return UpdateProfileRequest(driverDistance: draft.driverDistance);
      case ProfileField.swingSpeed:
        return UpdateProfileRequest(swingSpeed: draft.swingSpeed);
      case ProfileField.gender:
        return UpdateProfileRequest(gender: draft.gender?.value);
      case ProfileField.birthYear:
        return UpdateProfileRequest(birthYear: draft.birthYear);
      case ProfileField.country:
        return UpdateProfileRequest(country: draft.country);
      case ProfileField.imageUrl:
        return UpdateProfileRequest(imageUrl: draft.imageUrl);
    }
  }
}
