// Measure Panel — VSP Mobile App
//
// The readout for the manual measuring tool.
//
// Every number here is presented with the error bar it deserves. On 830 of our
// 900 holes there is no surveyed geometry, so this panel is often the only
// distance information a golfer has — dressing an estimate up as a
// measurement would be worse than showing nothing.

import 'package:flutter/material.dart';

import 'package:vsp_mobile/domain/value_objects/distance_measurement.dart';
import 'package:vsp_mobile/features/measure/domain/measure_leg.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/measure_state.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/presentation/widgets/distance/gps_accuracy_chip.dart';

/// Bottom readout showing every measured leg, the total, and GPS honesty.
class MeasurePanel extends StatelessWidget {
  /// Current measuring state.
  final MeasureState state;

  /// Removes the most recent point.
  final VoidCallback onUndo;

  /// Removes every point.
  final VoidCallback onClear;

  /// Switches between metres and yards.
  final VoidCallback onToggleUnit;

  /// Whether the map underneath is showing real imagery.
  ///
  /// False changes what the empty state tells the golfer to tap: "the bunker
  /// lip on the satellite image" is not advice you can follow when there is no
  /// satellite image.
  final bool imageryAvailable;

  /// Files the golfer's current position as where the green really is.
  ///
  /// Offered only where the panel has just admitted it does not know — an
  /// unknown or unsurveyed green — and only with a fix worth recording. That
  /// admission is the one moment the golfer is both standing on the answer and
  /// looking at the question; a correction form three taps deep in a More menu
  /// is a different, much rarer, act.
  ///
  /// Null hides the action entirely, which is what happens anywhere the caller
  /// has no course, hole or repository to file against.
  final VoidCallback? onReportGreenPosition;

  /// Set once a report has been filed for this hole, so the action becomes an
  /// acknowledgement instead of inviting a second identical report.
  final bool greenPositionReported;

  const MeasurePanel({
    super.key,
    required this.state,
    required this.onUndo,
    required this.onClear,
    required this.onToggleUnit,
    this.imageryAvailable = true,
    this.onReportGreenPosition,
    this.greenPositionReported = false,
  });

  /// Coarsest fix the correction API accepts.
  static const double _maxReportableAccuracyMeters = 100;

  static const Color _surface = Color(0xF2131C2F);
  static const Color _border = Color(0x33FFFFFF);
  static const Color _textPrimary = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _warning = Color(0xFFFBBF24);
  static const Color _danger = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, l10n),
            const SizedBox(height: 6),
            _buildGpsRow(context, l10n),
            // The green reading exists before the first tap does — when GPS
            // and a green position are both known, "from you to the green" is
            // already an answer — so the readout and the "drop a point" hint
            // are no longer alternatives.
            if (!state.result.isEmpty) ...[
              const SizedBox(height: 8),
              _buildLegs(context, l10n),
            ],
            if (state.isEmpty) ...[
              const SizedBox(height: 8),
              _buildEmpty(l10n),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        const Icon(Icons.straighten, size: 18, color: _textPrimary),
        const SizedBox(width: 6),
        // The title and the point count give way before the controls do.
        // "Đo khoảng cách" plus "Chưa có điểm" is wider than the 360 dp phones
        // most of our golfers carry, and an overflowing row loses the undo and
        // clear buttons entirely — the two things a mis-tapped point needs.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  l10n.measureTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.measurePoints(state.points.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        _UnitToggle(unit: state.unit, onToggle: onToggleUnit),
        const SizedBox(width: 4),
        IconButton(
          onPressed: state.isEmpty ? null : onUndo,
          icon: const Icon(Icons.undo, size: 20),
          color: _textPrimary,
          disabledColor: _textMuted,
          tooltip: l10n.measureUndo,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        IconButton(
          onPressed: state.isEmpty ? null : onClear,
          icon: const Icon(Icons.layers_clear_outlined, size: 20),
          color: _textPrimary,
          disabledColor: _textMuted,
          tooltip: l10n.measureClear,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ],
    );
  }

  // ─── GPS honesty ───────────────────────────────────────────────────────────

  Widget _buildGpsRow(BuildContext context, AppLocalizations l10n) {
    final origin = state.origin;
    final accuracy = origin?.accuracyMeters;

    // The green note used to be a casualty of a missing fix: no fix meant this
    // returned early, so a golfer who dropped a point without GPS still got an
    // "On to green" number — measured from that point, so it did not need GPS
    // at all — with nothing saying the green position was a guess. Losing the
    // fix is a reason to say more, not less.
    final warnings = <String>[
      if (!state.hasNoFix && origin!.isStale) l10n.measureStaleFix,
      if (!state.hasNoFix && origin!.isLowAccuracy) l10n.measureWeakFix,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (state.hasNoFix)
              const Icon(Icons.gps_off, size: 14, color: _danger)
            else
              GpsAccuracyChip(
                level: _accuracyLevel(accuracy),
                accuracyMeters: accuracy,
              ),
            const SizedBox(width: 8),
            Expanded(child: _buildGreenNote(l10n)),
          ],
        ),
        if (_canReportGreen) ...[
          const SizedBox(height: 6),
          _GreenReportAction(
            label: greenPositionReported
                ? l10n.measureGreenReportSent
                : l10n.measureGreenReportAction,
            // A filed report changes nothing on this map until somebody
            // reviews it, so the button must stop looking like a fix.
            onTap: greenPositionReported ? null : onReportGreenPosition,
          ),
        ],
        if (state.hasNoFix) ...[
          const SizedBox(height: 6),
          _Notice(
            icon: Icons.gps_off,
            color: _danger,
            message: l10n.measureNoFix,
          ),
        ],
        for (final warning in warnings) ...[
          const SizedBox(height: 6),
          _Notice(
            icon: Icons.warning_amber_rounded,
            color: _warning,
            message: warning,
          ),
        ],
      ],
    );
  }

  /// Whether to offer the golfer's position as the green's.
  ///
  /// Requires all three: a caller that can file one, a green this panel has
  /// admitted uncertainty about, and a fix accurate enough to be worth a
  /// reviewer's time. A report pinned to a 300 m fix is noise that costs an
  /// admin the same attention as a good one.
  bool get _canReportGreen {
    if (onReportGreenPosition == null) return false;
    final unsure = state.green == null || state.result.greenIsEstimated;
    if (!unsure) return false;
    final accuracy = state.origin?.accuracyMeters;
    if (accuracy == null) return false;
    return accuracy <= _maxReportableAccuracyMeters;
  }

  Widget _buildGreenNote(AppLocalizations l10n) {
    final String text;
    final Color color;
    if (state.green == null) {
      text = l10n.measureGreenUnknown;
      color = _textMuted;
    } else if (state.result.greenIsEstimated) {
      text = l10n.measureGreenEstimated;
      color = _warning;
    } else {
      text = l10n.measureGreenSurveyed;
      color = _textMuted;
    }
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 11),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }

  static GpsAccuracyLevel _accuracyLevel(double? accuracyMeters) {
    if (accuracyMeters == null) return GpsAccuracyLevel.poor;
    if (accuracyMeters < 5) return GpsAccuracyLevel.excellent;
    if (accuracyMeters < 10) return GpsAccuracyLevel.good;
    if (accuracyMeters < 20) return GpsAccuracyLevel.moderate;
    return GpsAccuracyLevel.poor;
  }

  // ─── Distances ─────────────────────────────────────────────────────────────

  Widget _buildEmpty(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.measureEmptyTitle,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          imageryAvailable
              ? l10n.measureEmptyBody
              : l10n.measureEmptyBodyNoImagery,
          style: const TextStyle(color: _textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLegs(BuildContext context, AppLocalizations l10n) {
    final result = state.result;
    final unit = state.unit;
    final rows = <Widget>[];

    var pointIndex = 0;
    for (final leg in result.legs) {
      final String label;
      if (leg.kind == MeasureLegKind.fromGolfer) {
        label = l10n.measureFromYou;
        pointIndex = 1;
      } else {
        pointIndex += 1;
        label = l10n.measureLegLabel('$pointIndex');
      }
      rows.add(_LegRow(label: label, leg: leg, unit: unit));
    }

    final greenLeg = result.greenLeg;
    if (greenLeg != null) {
      rows.add(
        _LegRow(
          label: result.greenLegIsFromGolfer
              ? l10n.measureYouToGreen
              : l10n.measureToGreen,
          leg: greenLeg,
          unit: unit,
          emphasised: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        if (result.legs.length > 1) ...[
          const Divider(color: _border, height: 12),
          _TotalRow(
            label: l10n.measureTotal,
            meters: result.totalMeters,
            toleranceMeters: result.totalUncertaintyMeters,
            unit: unit,
          ),
        ],
        if (!result.hasGolferOrigin && state.points.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.measureNoFix,
            style: const TextStyle(color: _danger, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

// ─── Rows ────────────────────────────────────────────────────────────────────

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
    final tolerance = MeasureUnits.formatTolerance(
      leg.uncertaintyMeters,
      unit,
    );

    return Semantics(
      label: l10n.measureSemanticsLeg(label, distance, tolerance),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: emphasised
                      ? const Color(0xFF68DBA9)
                      : MeasurePanel._textMuted,
                  fontSize: 12,
                  fontWeight: emphasised ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              distance,
              style: const TextStyle(
                color: MeasurePanel._textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tolerance,
              style: TextStyle(
                color: _toleranceColor(leg.quality),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _toleranceColor(MeasureQuality quality) {
    switch (quality) {
      case MeasureQuality.good:
        return const Color(0xFF68DBA9);
      case MeasureQuality.fair:
        return const Color(0xFF94A3B8);
      case MeasureQuality.poor:
        return const Color(0xFFFBBF24);
      case MeasureQuality.unusable:
        return const Color(0xFFF87171);
    }
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double meters;
  final double toleranceMeters;
  final DistanceUnit unit;

  const _TotalRow({
    required this.label,
    required this.meters,
    required this.toleranceMeters,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final distance = MeasureUnits.format(meters, unit);
    final tolerance = MeasureUnits.formatTolerance(toleranceMeters, unit);

    return Semantics(
      label: l10n.measureSemanticsLeg(label, distance, tolerance),
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: MeasurePanel._textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            distance,
            style: const TextStyle(
              color: MeasurePanel._textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          Text(
            tolerance,
            style: const TextStyle(
              color: MeasurePanel._textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
            border: Border.all(color: MeasurePanel._border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            MeasureUnits.suffix(unit),
            style: const TextStyle(
              color: MeasurePanel._textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
        const SizedBox(width: 6),
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

/// The one-tap "the green is here" action.
///
/// Deliberately a quiet outlined row rather than a filled button: it is an
/// offer to help, next to an admission of ignorance, and it must not compete
/// with the distances the golfer opened this panel to read.
class _GreenReportAction extends StatelessWidget {
  final String label;

  /// Null once a report has been filed — the row stays, greyed, so the golfer
  /// can see their report was taken without being invited to file it twice.
  final VoidCallback? onTap;

  const _GreenReportAction({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sent = onTap == null;
    final color = sent
        ? MeasurePanel._textMuted
        : MeasurePanel._textPrimary;

    return Semantics(
      button: !sent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: MeasurePanel._border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sent ? Icons.check_circle_outline : Icons.add_location_alt_outlined,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
