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
      final state = BlocProvider.of<ProfileBloc>(context, listen: false).state;
      if (state is ProfileLoaded) {
        return state.profile.distanceUnit;
      }
    } on ProviderNotFoundException {
      // No profile in scope on this route — fall through to the caller's
      // preference rather than guessing.
    }
    return fallback;
  }
}
