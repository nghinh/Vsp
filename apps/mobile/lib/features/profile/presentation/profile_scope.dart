// Profile Scope — VSP Mobile App
//
// Puts a [ProfileBloc] in scope for subtrees that need the golfer's saved
// preferences but do not own the profile screen.
//
// The distance-unit preference is the reason this exists. It lives on the
// profile, and DistanceUnitScope looks for a ProfileBloc in context — but the
// only ProfileBloc in the app was created inside ProfileScreen, nowhere near
// the round or the map, so every distance a golfer saw during a round fell
// back to metres no matter what they had saved.
//
// The bloc is created lazily: nothing here costs a network call until
// something below actually asks for the profile. The repository is shared
// across scopes so the profile is fetched once per app run rather than once
// per screen — its cache is per-instance.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_bloc.dart';
import '../../../core/storage/profile_sync_store.dart';
import '../data/profile_repository.dart';
import '../data/profile_service.dart';
import 'profile_bloc.dart';

/// Provides a [ProfileBloc] to [child], unless one is already in scope.
class ProfileScope extends StatelessWidget {
  const ProfileScope({super.key, required this.child, this.profileBloc});

  final Widget child;

  /// Injectable for tests and for callers that already own a bloc.
  final ProfileBloc? profileBloc;

  static ProfileRepository? _sharedRepository;

  /// The app-wide profile repository, built on first use.
  ///
  /// Shared deliberately: [ProfileRepository] caches the profile in memory, so
  /// a per-screen instance would refetch on every screen and lose the cache
  /// the moment the screen closed.
  static ProfileRepository get sharedRepository {
    return _sharedRepository ??= ProfileRepository(
      profileService: ProfileService(apiClient: ApiClient()),
      syncStore: ProfileSyncStore(),
    );
  }

  @visibleForTesting
  static set sharedRepository(ProfileRepository repository) {
    _sharedRepository = repository;
  }

  @override
  Widget build(BuildContext context) {
    final injected = profileBloc;
    if (injected != null) {
      return BlocProvider<ProfileBloc>.value(value: injected, child: child);
    }

    // Nested scopes (the round screen wraps the map screen) must not create a
    // second bloc — two profiles in one tree is two answers to one question.
    try {
      // context.read rather than BlocProvider.of: the latter turns a missing
      // provider into a FlutterError that cannot be caught by type.
      context.read<ProfileBloc>();
      return child;
    } on ProviderNotFoundException {
      // Nothing above provides one; fall through and create it.
    }

    return BlocProvider<ProfileBloc>(
      create: (_) =>
          ProfileBloc(profileRepository: sharedRepository)
            ..add(const LoadProfile()),
      child: _ReloadsOnSignIn(child: child),
    );
  }
}

/// Refetches the profile whenever a golfer signs in.
///
/// This scope now sits above the Navigator and so lives as long as the app
/// does. That is what makes the unit preference reach every route, and it is
/// also why this is needed: the bloc used to be rebuilt on every screen that
/// wanted it, which refetched by accident. One long-lived bloc keeps the
/// profile of whoever signed in first, so the second golfer to use the phone
/// would see the first golfer's units — and their handicap, and their home
/// club.
///
/// Does nothing where no [AuthBloc] is in scope, which is the case in the
/// widget tests that build a screen on its own.
class _ReloadsOnSignIn extends StatelessWidget {
  const _ReloadsOnSignIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AuthBloc auth;
    try {
      auth = context.read<AuthBloc>();
    } on ProviderNotFoundException {
      return child;
    }

    return BlocListener<AuthBloc, AuthState>(
      bloc: auth,
      listenWhen: (_, current) =>
          current is AuthSuccess || current is SessionRestored,
      listener: (listenerContext, _) =>
          listenerContext.read<ProfileBloc>().add(const LoadProfile()),
      child: child,
    );
  }
}
