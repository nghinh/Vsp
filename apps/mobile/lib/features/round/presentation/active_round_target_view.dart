// Active Round Target View — VSP Mobile App
//
// The Target tab of an active round.
//
// It used to be a leaflet: hole number, par, length, and a sentence telling the
// golfer the distance lives on the other tab. It could not do better, because
// the HoleMapBloc that owns the placed target was created inside HoleMapScreen,
// below the tab stack — no sibling tab could see it. The bloc now lives above
// the tabs, so this tab reads the very same target the golfer dropped on the
// map and the very same GPS stream, and both numbers move as they walk.
//
// Both distances come from [TargetDistanceReading], which is [MeasureCalculator]
// underneath — the same geodesy and the same ± presentation the measuring tool
// uses. Where an input is missing the number is missing with it: no GPS fix
// means no "from you" distance, and an unknown green means no "on to green"
// distance. A figure derived from a guessed position would be read as a club
// selection.
//
// Above the target readout sit the three numbers a golfer looks at before every
// approach — front, centre and back of the green — from [GreenDistanceReading].
// They need no target, so they are there the moment the hole opens on a course
// whose package draws the green as a shape. They replace an orphaned screen
// that promised the same three distances from a parallel geometry model the app
// never populated, and so would have shown "No hole data" on every hole.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart'
    show GpsAccuracyLevel;
import 'package:vsp_mobile/features/hole_map/domain/green_distance_reading.dart';
import 'package:vsp_mobile/features/hole_map/domain/hole_geometry_coverage.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_bloc.dart';
import 'package:vsp_mobile/features/hole_map/presentation/hole_map_state.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/features/target/domain/target_distance_reading.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';
import 'package:vsp_mobile/presentation/widgets/distance/gps_accuracy_chip.dart';
import 'package:vsp_mobile/presentation/widgets/distance/not_surveyed_chip.dart';

/// Key of the live readout, so tests can find it without matching prose.
const Key activeRoundTargetReadoutKey = ValueKey('active-round-target-readout');

/// Key of the front/centre/back green readout.
const Key activeRoundGreenReadoutKey = ValueKey('active-round-green-readout');

/// Target tab body — live distances for the target placed on the hole map.
class ActiveRoundTargetView extends StatefulWidget {
  /// Current hole number, shown as context.
  final int holeNumber;

  /// Par for the hole, or null when the course data does not carry it.
  final int? par;

  /// Hole length in metres, or null when it is not known.
  final int? yardage;

  /// Starting display unit when no ProfileBloc is in scope.
  final DistanceUnit? distanceUnit;

  /// Switches the round to the Map tab.
  ///
  /// With no target placed this tab's whole content is a sentence telling the
  /// golfer to go and tap the map — and it left them to find their own way
  /// there. The instruction and the way to follow it belong together.
  final VoidCallback? onOpenMap;

  const ActiveRoundTargetView({
    super.key,
    required this.holeNumber,
    this.par,
    this.yardage,
    this.distanceUnit,
    this.onOpenMap,
  });

  @override
  State<ActiveRoundTargetView> createState() => _ActiveRoundTargetViewState();
}

class _ActiveRoundTargetViewState extends State<ActiveRoundTargetView> {
  DistanceUnit? _unit;

  /// Golfer's unit, resolved from the profile the first time it is needed.
  ///
  /// Deferred to build because the profile usually is not loaded yet when this
  /// tab is first created; [DistanceUnitScope.listen] then keeps it current.
  DistanceUnit _resolveUnit(BuildContext context) =>
      _unit ??= DistanceUnitScope.resolve(
        context,
        fallback: widget.distanceUnit ?? DistanceUnit.meters,
      );

  void _toggleUnit() {
    setState(() {
      _unit = _unit == DistanceUnit.yards
          ? DistanceUnit.meters
          : DistanceUnit.yards;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = _resolveUnit(context);

    return DistanceUnitScope.listen(
      context: context,
      onUnit: (_, profileUnit) => setState(() => _unit = profileUnit),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.activeRoundTarget,
            style: TextStyle(color: VspTextTiers.of(context).primary),
          ),
          iconTheme: IconThemeData(color: VspTextTiers.of(context).primary),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(VspSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Inside the builder so the length chip can see the hole's
              // provenance. A hole that is loading, errored or unsurveyed has
              // no provenance to show, and that is exactly when the number
              // must not look authoritative.
              BlocBuilder<HoleMapBloc, HoleMapState>(
                builder: (context, state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HoleContextRow(
                      holeNumber: widget.holeNumber,
                      par: widget.par,
                      yardage: widget.yardage,
                      yardageIsSurveyed:
                          state is HoleMapReady && state.holeMap.isSurveyed,
                    ),
                    const SizedBox(height: VspSpacing.md),
                    _buildBody(context, state, unit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HoleMapState state,
    DistanceUnit unit,
  ) {
    final l10n = AppLocalizations.of(context);

    if (state is HoleMapUnsurveyed) {
      return _TargetMessageCard(
        icon: Icons.satellite_alt_outlined,
        heading: l10n.activeRoundTargetUnsurveyedHeading,
        message: l10n.activeRoundTargetUnsurveyedMessage,
      );
    }

    if (state is HoleMapError) {
      return _TargetMessageCard(
        icon: Icons.error_outline,
        heading: l10n.activeRoundTargetHeading,
        message: context.tr(state.message),
      );
    }

    if (state is! HoleMapReady) {
      return _TargetMessageCard(
        icon: Icons.gps_not_fixed,
        heading: l10n.activeRoundTargetHeading,
        message: l10n.activeRoundTargetLoading,
      );
    }

    final fix = context.read<HoleMapBloc>().lastFix;

    final reading = TargetDistanceReading.of(
      target: state.target,
      golfer: fix,
      green: HoleGeometryCoverage.greenAnchor(state.holeMap),
    );

    // Front / centre / back stand on their own: they need the green and a fix,
    // not a target, so they are useful the moment the hole opens.
    final green = GreenDistanceReading.of(holeMap: state.holeMap, golfer: fix);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (green.hasDistances) ...[
          GreenReadout(
            reading: green,
            unit: unit,
            onToggleUnit: _toggleUnit,
          ),
          const SizedBox(height: VspSpacing.md),
        ],
        if (!reading.hasTarget)
          _TargetMessageCard(
            icon: Icons.gps_fixed,
            heading: l10n.activeRoundTargetHeading,
            message: l10n.activeRoundTargetMessage,
            actionLabel: widget.onOpenMap == null
                ? null
                : l10n.activeRoundTargetOpenMap,
            onAction: widget.onOpenMap,
          )
        else
          _TargetReadout(
            reading: reading,
            unit: unit,
            onToggleUnit: _toggleUnit,
          ),
      ],
    );
  }
}

// ─── Green readout ──────────────────────────────────────────────────────────

/// Front, centre and back of the green from where the golfer is standing.
/// Front, centre and back of the green from where the golfer is standing.
///
/// Public so the size hierarchy it exists for can be tested without standing
/// up a round, a bloc and a GPS stream to find out whether one number is
/// bigger than another.
class GreenReadout extends StatelessWidget {
  final GreenDistanceReading reading;
  final DistanceUnit unit;
  final VoidCallback onToggleUnit;

  const GreenReadout({
    required this.reading,
    required this.unit,
    required this.onToggleUnit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: activeRoundGreenReadoutKey,
      padding: const EdgeInsets.all(VspSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.golf_course,
                size: VspIconSize.sm,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.xs),
              Expanded(
                child: Text(
                  l10n.activeRoundGreenHeading,
                  style: TextStyle(
                    color: VspTextTiers.of(context).primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _UnitToggle(unit: unit, onToggle: onToggleUnit),
            ],
          ),
          const SizedBox(height: VspSpacing.sm),

          // The number a club is chosen off, at the size that decision
          // deserves.
          //
          // Front, centre and back used to be three identical rows: same
          // 22pt figure, same weight, and "emphasised" changed the colour of
          // the *label* while leaving the number indistinguishable. So the one
          // distance a golfer actually plays looked exactly like the two that
          // bracket it, on a screen read at arm's length, one-handed, in sun.
          // Every rangefinder ever made leads with the centre and prints the
          // edges small, and it is not a house style — it is which number the
          // shot is played to.
          _HeroDistance(
            label: l10n.activeRoundGreenCentre,
            leg: reading.centre!,
            unit: unit,
          ),
          const SizedBox(height: VspSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _EdgeDistance(
                  label: l10n.activeRoundGreenFront,
                  leg: reading.front!,
                  unit: unit,
                ),
              ),
              Expanded(
                child: _EdgeDistance(
                  label: l10n.activeRoundGreenBack,
                  leg: reading.back!,
                  unit: unit,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            l10n.activeRoundGreenMeasuredNote,
            style: TextStyle(
              color: VspTextTiers.of(context).tertiary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live readout ───────────────────────────────────────────────────────────

class _TargetReadout extends StatelessWidget {
  final TargetDistanceReading reading;
  final DistanceUnit unit;
  final VoidCallback onToggleUnit;

  const _TargetReadout({
    required this.reading,
    required this.unit,
    required this.onToggleUnit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fix = reading.fix;

    return Container(
      key: activeRoundTargetReadoutKey,
      padding: const EdgeInsets.all(VspSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gps_fixed,
                size: VspIconSize.sm,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: VspSpacing.xs),
              Expanded(
                child: Text(
                  l10n.activeRoundTargetHeading,
                  style: TextStyle(
                    color: VspTextTiers.of(context).primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _UnitToggle(unit: unit, onToggle: onToggleUnit),
            ],
          ),
          const SizedBox(height: VspSpacing.sm),

          // GPS honesty, exactly as the measuring tool presents it.
          if (fix == null)
            _Notice(
              icon: Icons.gps_off,
              color: Theme.of(context).colorScheme.error,
              message: l10n.measureNoFix,
            )
          else ...[
            Row(
              children: [
                GpsAccuracyChip(
                  level: _accuracyLevel(fix.accuracyMeters),
                  accuracyMeters: fix.accuracyMeters,
                ),
                const SizedBox(width: VspSpacing.sm),
                Expanded(child: _greenNote(context, l10n)),
              ],
            ),
            if (fix.isStale) ...[
              const SizedBox(height: VspSpacing.xs),
              _Notice(
                icon: Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.secondary,
                message: l10n.measureStaleFix,
              ),
            ],
            if (fix.isLowAccuracy) ...[
              const SizedBox(height: VspSpacing.xs),
              _Notice(
                icon: Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.secondary,
                message: l10n.measureWeakFix,
              ),
            ],
          ],

          const SizedBox(height: VspSpacing.sm),

          // Golfer → target.
          if (reading.fromGolfer != null)
            _LegRow(
              label: l10n.measureFromYou,
              leg: reading.fromGolfer!,
              unit: unit,
            ),

          // Target → green.
          if (reading.onToGreen != null)
            _LegRow(
              label: l10n.measureToGreen,
              leg: reading.onToGreen!,
              unit: unit,
              emphasised: true,
            )
          else if (reading.greenUnknown)
            _Notice(
              icon: Icons.help_outline,
              color: VspTextTiers.of(context).tertiary,
              message: l10n.measureGreenUnknown,
            ),

          const SizedBox(height: VspSpacing.sm),
          Text(
            l10n.activeRoundTargetMeasuredNote,
            style: TextStyle(
              color: VspTextTiers.of(context).tertiary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _greenNote(BuildContext context, AppLocalizations l10n) {
    final String text;
    final Color color;
    if (reading.greenUnknown) {
      text = l10n.measureGreenUnknown;
      color = VspTextTiers.of(context).tertiary;
    } else if (reading.greenIsEstimated) {
      text = l10n.measureGreenEstimated;
      color = Theme.of(context).colorScheme.secondary;
    } else {
      text = l10n.measureGreenSurveyed;
      color = VspTextTiers.of(context).tertiary;
    }
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 11),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  static GpsAccuracyLevel _accuracyLevel(double? accuracyMeters) {
    if (accuracyMeters == null) return GpsAccuracyLevel.poor;
    if (accuracyMeters < 5) return GpsAccuracyLevel.excellent;
    if (accuracyMeters < 10) return GpsAccuracyLevel.good;
    if (accuracyMeters < 20) return GpsAccuracyLevel.moderate;
    return GpsAccuracyLevel.poor;
  }
}

/// The distance the shot is played to.
///
/// Sized to be read without stopping to read it: a glance from a standing
/// golfer holding a club in the other hand. The unit sits beside the figure
/// rather than under it so the pair reads as one thing, and the error bar sits
/// under both because it qualifies the number without competing with it.
class _HeroDistance extends StatelessWidget {
  const _HeroDistance({
    required this.label,
    required this.leg,
    required this.unit,
  });

  final String label;
  final MeasureLeg leg;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = MeasureUnits.format(leg.meters, unit);
    final tolerance = MeasureUnits.formatTolerance(leg.uncertaintyMeters, unit);

    return Semantics(
      label: l10n.measureSemanticsLeg(label, distance, tolerance),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Not upper-cased here. Styling an eyebrow is this widget's
            // business; rewriting the words is the translation's, and a widget
            // that transforms them makes the string on screen something no
            // .arb file contains.
            label,
            style: TextStyle(
              color: VspTextTiers.of(context).secondary,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Wrap, not Row. The distance is the one thing on this screen that
          // must not shrink, so at a larger text size it is the error bar that
          // moves to the next line — a Row would have squeezed them both and
          // then overflowed, which is what it did at 1.3x.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: VspSpacing.xs,
            children: [
              Text(
                distance,
                style: TextStyle(
                  color: VspTextTiers.of(context).primary,
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  // Tabular, so the figure does not jump sideways as the
                  // golfer walks and the distance ticks down.
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                tolerance,
                style: TextStyle(
                  color: _LegRow._toleranceColor(context, leg.quality),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Front or back of the green — the bracket around the number above.
class _EdgeDistance extends StatelessWidget {
  const _EdgeDistance({
    required this.label,
    required this.leg,
    required this.unit,
    this.alignEnd = false,
  });

  final String label;
  final MeasureLeg leg;
  final DistanceUnit unit;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = MeasureUnits.format(leg.meters, unit);
    final tolerance = MeasureUnits.formatTolerance(leg.uncertaintyMeters, unit);

    return Semantics(
      label: l10n.measureSemanticsLeg(label, distance, tolerance),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: VspTextTiers.of(context).tertiary,
              fontSize: 11,
            ),
          ),
          Text(
            distance,
            style: TextStyle(
              color: VspTextTiers.of(context).secondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  final String label;
  final MeasureLeg leg;
  final DistanceUnit unit;
  final bool emphasised;

  const _LegRow({
    required this.label,
    required this.leg,
    required this.unit,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = MeasureUnits.format(leg.meters, unit);
    final tolerance = MeasureUnits.formatTolerance(leg.uncertaintyMeters, unit);

    return Semantics(
      label: l10n.measureSemanticsLeg(label, distance, tolerance),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: emphasised
                      ? Theme.of(context).colorScheme.primary
                      : VspTextTiers.of(context).secondary,
                  fontSize: 12,
                  fontWeight: emphasised ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              distance,
              style: TextStyle(
                color: VspTextTiers.of(context).primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: VspSpacing.xs),
            Text(
              tolerance,
              style: TextStyle(
                color: _toleranceColor(context, leg.quality),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _toleranceColor(BuildContext context, MeasureQuality quality) {
    switch (quality) {
      case MeasureQuality.good:
        return Theme.of(context).colorScheme.tertiary;
      case MeasureQuality.fair:
        return VspTextTiers.of(context).secondary;
      case MeasureQuality.poor:
        return Theme.of(context).colorScheme.secondary;
      case MeasureQuality.unusable:
        return Theme.of(context).colorScheme.error;
    }
  }
}

// ─── Supporting widgets ─────────────────────────────────────────────────────

class _HoleContextRow extends StatelessWidget {
  final int holeNumber;
  final int? par;
  final int? yardage;

  /// Whether the coordinates this length was measured between were verified.
  final bool yardageIsSurveyed;

  const _HoleContextRow({
    required this.holeNumber,
    this.par,
    this.yardage,
    this.yardageIsSurveyed = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Wrap, not Row: the unverified marker adds a chip's width to a line that
    // already fills a narrow phone, and a hole number pushed off the right
    // edge is worse than one on a second line.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Chip(label: l10n.activeRoundHole, value: '$holeNumber'),
        if (par != null) _Chip(label: l10n.fieldPar, value: '$par'),
        if (yardage != null) ...[
          if (!yardageIsSurveyed) const NotSurveyedChip(iconOnly: true),
          _Chip(
            label: l10n.activeRoundLength,
            value: context.formatDistance(yardage!.toDouble()),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;

  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VspSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VspSpacing.md,
          vertical: VspSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: VspTextTiers.of(context).primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: VspSpacing.half),
            Text(
              label,
              style: TextStyle(
                color: VspTextTiers.of(context).tertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetMessageCard extends StatelessWidget {
  final IconData icon;
  final String heading;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _TargetMessageCard({
    required this.icon,
    required this.heading,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: VspSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: VspSpacing.md),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VspTextTiers.of(context).primary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: VspSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VspTextTiers.of(context).secondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: VspSpacing.lg),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.map_outlined),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _Notice({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: VspSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final DistanceUnit unit;
  final VoidCallback onToggle;

  const _UnitToggle({required this.unit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.distanceToggleUnit(MeasureUnits.suffix(unit)),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            MeasureUnits.suffix(unit),
            style: TextStyle(
              color: VspTextTiers.of(context).primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
