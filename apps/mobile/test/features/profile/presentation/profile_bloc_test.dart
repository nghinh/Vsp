// ProfileBloc error-path tests — VSP Mobile App
//
// The load path used to catch everything bare and emit the same sentence:
// a 401 whose refresh had already failed, a 500, and a JSON parse error all
// rendered "Không tải được hồ sơ" with a retry button that could not help.
// These tests pin the split: a 401 is a dead session and must become
// ProfileSessionExpired; everything else keeps the generic headline but
// carries the specific cause in `detail`.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart';
import 'package:vsp_mobile/features/profile/data/profile_repository.dart';
import 'package:vsp_mobile/features/profile/presentation/profile_bloc.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

class FakeProfileRepository implements ProfileRepository {
  Object? getProfileError;
  ProfileDTO? profile;
  Object? updateError;

  @override
  Future<ProfileDTO> getProfile() async {
    final error = getProfileError;
    if (error != null) throw error;
    return profile!;
  }

  @override
  ProfileDTO? getCachedProfile() => null;

  @override
  Future<bool> hasPending() async => false;

  @override
  Future<ProfileUpdateResult> queueProfileUpdate(
    UpdateProfileRequest request,
  ) async {
    final error = updateError;
    if (error != null) throw error;
    return ProfileUpdateResult(
      queuedOffline: false,
      serverProfile: profile,
      idempotencyKey: 'test-key',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

ProfileDTO _profile() => const ProfileDTO(id: 1, golferAccountId: 10);

void main() {
  group('LoadProfile error paths', () {
    blocTest<ProfileBloc, ProfileState>(
      'a 401 becomes ProfileSessionExpired, not a retryable error',
      build: () {
        final repo = FakeProfileRepository()
          ..getProfileError = const VspApiException(
            code: 'VSP-ERR-AUTH-001',
            message: 'Authentication required',
            statusCode: 401,
          );
        return ProfileBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(const LoadProfile()),
      expect: () => [
        const ProfileLoading(),
        const ProfileSessionExpired(),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'a non-401 API error keeps the headline and carries the cause',
      build: () {
        final repo = FakeProfileRepository()
          ..getProfileError = const VspApiException(
            code: 'VSP-ERR-INTERNAL-001',
            message: AppMessages.serverError,
            statusCode: 500,
          );
        return ProfileBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(const LoadProfile()),
      expect: () => [
        const ProfileLoading(),
        const ProfileError(
          message: AppMessages.profileLoadFailed,
          detail: AppMessages.serverError,
        ),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'an unexpected exception still surfaces what happened',
      build: () {
        final repo = FakeProfileRepository()
          ..getProfileError = const FormatException('bad json');
        return ProfileBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(const LoadProfile()),
      expect: () => [
        const ProfileLoading(),
        const ProfileError(
          message: AppMessages.profileLoadFailed,
          detail: 'FormatException: bad json',
        ),
      ],
    );
  });

  group('SaveField error paths', () {
    blocTest<ProfileBloc, ProfileState>(
      'a 401 during save becomes ProfileSessionExpired',
      build: () {
        final repo = FakeProfileRepository()
          ..profile = _profile()
          ..updateError = const VspApiException(
            code: 'VSP-ERR-AUTH-001',
            message: 'Authentication required',
            statusCode: 401,
          );
        return ProfileBloc(profileRepository: repo);
      },
      act: (bloc) async {
        bloc.add(const LoadProfile());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SaveField(field: ProfileField.homeClub));
      },
      skip: 2, // ProfileLoading, ProfileLoaded
      expect: () => [
        isA<ProfileLoaded>(), // savingField set
        const ProfileSessionExpired(),
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'a non-401 save error keeps the draft and carries the cause',
      build: () {
        final repo = FakeProfileRepository()
          ..profile = _profile()
          ..updateError = const VspApiException(
            code: 'VSP-ERR-VALIDATION-001',
            message: 'handicap out of range',
            statusCode: 422,
          );
        return ProfileBloc(profileRepository: repo);
      },
      act: (bloc) async {
        bloc.add(const LoadProfile());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SaveField(field: ProfileField.homeClub));
      },
      skip: 2,
      expect: () => [
        isA<ProfileLoaded>(),
        isA<ProfileError>()
            .having((s) => s.message, 'message', AppMessages.profileSaveFailed)
            .having((s) => s.detail, 'detail', 'handicap out of range')
            .having((s) => s.lastProfile, 'lastProfile', isNotNull),
      ],
    );
  });
}
