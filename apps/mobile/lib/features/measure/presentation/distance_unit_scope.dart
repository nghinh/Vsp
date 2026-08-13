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

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
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

  /// The profile's unit, rebuilding the caller when it becomes known.
  ///
  /// [resolve] answers with whatever is loaded at the instant it is called and
  /// does not subscribe, so a widget that used it got metres on its first
  /// build — the profile is still in flight then, because opening a screen is
  /// what triggers the fetch — and never rebuilt to correct itself. That is
  /// why the map screens pair [resolve] with [listen]. A widget that simply
  /// draws a number wants neither; it wants to be rebuilt, which is this.
  ///
  /// Safe in `build` and in `didChangeDependencies`, the two places a widget is
  /// allowed to take a dependency.
  static DistanceUnit watch(
    BuildContext context, {
    DistanceUnit fallback = DistanceUnit.meters,
  }) {
    try {
      final state = context.watch<ProfileBloc>().state;
      if (state is ProfileLoaded) {
        return state.profile.distanceUnit;
      }
    } on ProviderNotFoundException {
      // No profile on this route — the caller's preference stands.
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

/// Formatting a distance in the golfer's own unit, from any widget.
///
/// Every distance in this app is stored in metres and converted once, here, at
/// the moment it is drawn. The extension exists because the alternative kept
/// losing: a screen that has to remember to look up the preference is a screen
/// that will one day be written without doing so, and the app accumulated
/// roughly forty places printing a hardcoded `m` or `yd` — including two that
/// disagreed about the same club's carry distance, metres in the bag and yards
/// in the shot entry picker.
extension DistanceFormatting on BuildContext {
  /// The golfer's saved unit, or metres where no profile is in scope.
  ///
  /// Subscribes, so the widget reading it is rebuilt when the profile finishes
  /// loading. Reading without subscribing is how a screen ends up showing
  /// metres for the rest of its life to a golfer who saved yards.
  DistanceUnit get distanceUnit => DistanceUnitScope.watch(this);

  /// Canonical metres as the golfer would read them, e.g. `152 m` / `166 yd`.
  ///
  /// Null renders as an em dash rather than as a zero: a distance nobody has
  /// measured is not a distance of nothing.
  String formatDistance(double? meters, {String ifNull = '—'}) =>
      meters == null ? ifNull : MeasureUnits.format(meters, distanceUnit);

  /// The bare number, for places that draw the unit separately.
  int? distanceValue(double? meters) =>
      meters == null ? null : MeasureUnits.displayValue(meters, distanceUnit);

  /// `m` or `yd`.
  String get distanceSuffix => MeasureUnits.suffix(distanceUnit);

  /// Converts what the golfer typed, in their own unit, back to metres.
  ///
  /// The inverse of the above, and the reason it lives beside it: an input
  /// labelled in yards that stores its number unconverted is worse than a
  /// display bug, because the wrong value outlives the screen.
  double toCanonicalMeters(double typed) => distanceUnit == DistanceUnit.yards
      ? typed / MeasureUnits.metersToYards
      : typed;
}
