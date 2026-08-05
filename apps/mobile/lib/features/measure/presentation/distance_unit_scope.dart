// Distance Unit Scope — VSP Mobile App
//
// Resolves the golfer's metres/yards preference for screens that are not
// already inside a distance-aware BLoC.
//
// The preference lives on the golfer profile. Wherever a ProfileBloc happens
// to be in scope we use it; where it is not, callers pass an explicit unit and
// the golfer can still flip the toggle in the measuring panel. Canonical
// values stay in metres either way — only the display changes.

import 'package:flutter/widgets.dart';
// ProviderNotFoundException is re-exported by flutter_bloc, so no direct
// dependency on package:provider is needed.
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/profile/presentation/profile_bloc.dart';

/// Reads the golfer's distance-unit preference from context.
abstract final class DistanceUnitScope {
  /// Returns the profile's unit when a [ProfileBloc] is in scope with a loaded
  /// profile, otherwise [fallback].
  static DistanceUnit resolve(
    BuildContext context, {
    DistanceUnit fallback = DistanceUnit.meters,
  }) {
    try {
      // context.read, not BlocProvider.of: BlocProvider.of rewrites a missing
      // provider into a FlutterError, which no `on ProviderNotFoundException`
      // catch can see — so this used to throw on any route without a profile
      // instead of falling back.
      final state = context.read<ProfileBloc>().state;
      if (state is ProfileLoaded) {
        return state.profile.distanceUnit;
      }
    } on ProviderNotFoundException {
      // No profile in scope on this route — fall through to the caller's
      // preference rather than guessing.
    }
    return fallback;
  }

  /// Wraps [child] so [onUnit] fires whenever the profile's unit becomes known
  /// or changes.
  ///
  /// [resolve] answers with whatever is known *now*, which is metres while the
  /// profile is still loading — and the profile usually is, because opening the
  /// map is what triggers the fetch. Without this the golfer would see metres
  /// for the rest of the round despite having saved yards.
  ///
  /// Returns [child] unchanged where no [ProfileBloc] is in scope, so screens
  /// and tests without a profile keep working.
  static Widget listen({
    required BuildContext context,
    required Widget child,
    required void Function(BuildContext context, DistanceUnit unit) onUnit,
  }) {
    final ProfileBloc bloc;
    try {
      bloc = context.read<ProfileBloc>();
    } on ProviderNotFoundException {
      return child;
    }

    return BlocListener<ProfileBloc, ProfileState>(
      bloc: bloc,
      listenWhen: (previous, current) =>
          current is ProfileLoaded &&
          (previous is! ProfileLoaded ||
              previous.profile.distanceUnit != current.profile.distanceUnit),
      listener: (listenerContext, state) {
        if (state is ProfileLoaded) {
          onUnit(listenerContext, state.profile.distanceUnit);
        }
      },
      child: child,
    );
  }
}
