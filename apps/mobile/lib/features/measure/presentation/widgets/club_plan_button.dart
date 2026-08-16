// "Chia gậy giúp tôi" — VSP Mobile App
//
// One control over the satellite photograph. It reads where the golfer is,
// where the green is, and what is in their bag, and drops the shots between
// them into the measuring tool.
//
// It drops points and then gets out of the way. There is no mode to leave and
// nothing to confirm: what lands on the map is the same chain the golfer
// builds by tapping, so the next thing they do is drag the layup off the
// bunker they can see under it. Pressing again re-plans from wherever they now
// stand; the second press clears it, because a suggestion you cannot dismiss
// is a decision.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vsp_mobile/domain/value_objects/lat_lng.dart';
import 'package:vsp_mobile/features/measure/domain/club_plan.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_cubit.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class ClubPlanButton extends StatelessWidget {
  const ClubPlanButton({super.key, required this.clubs});

  final List<PlannedClub> clubs;

  @override
  Widget build(BuildContext context) {
    if (clubs.isEmpty) return const SizedBox.shrink();

    return BlocBuilder<MeasureCubit, MeasureState>(
      builder: (context, state) {
        final shots = _plan(state);
        // Nothing to divide: no fix, no green, or the golfer is on it.
        if (shots.isEmpty && state.points.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context);
        final planned = state.points.isNotEmpty;
        return Material(
          color: planned ? const Color(0xFF334155) : const Color(0xFFEA580C),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => planned
                ? context.read<MeasureCubit>().clear()
                : context.read<MeasureCubit>().applyPlan(
                      // The flag is where the last shot finishes and the tool
                      // measures to it already. A point sitting on it would be
                      // a marker the golfer has to delete before the number
                      // reads right.
                      [for (final shot in shots.take(shots.length - 1))
                        shot.aimPoint],
                    ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(planned ? Icons.close : Icons.route,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    planned ? l10n.measurePlanClear : l10n.measurePlanSuggest,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The shots between the golfer and the green, if both are known.
  List<PlannedShot> _plan(MeasureState state) {
    final origin = state.origin;
    final green = state.green;
    if (origin == null || green == null) return const [];
    return ClubPlanner.plan(
      from: LatLng(latitude: origin.latitude, longitude: origin.longitude),
      to: green.position,
      clubs: clubs,
    );
  }
}
