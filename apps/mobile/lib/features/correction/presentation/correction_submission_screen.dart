// CorrectionSubmissionScreen — VSP Mobile App
//
// Full-screen form for submitting a course-data correction.
//
// Per Story 9.1 Slice 3: Submission form UI.
//
// AC fields: issue type, course, hole, location, accuracy, timestamp,
// optional note. Saves offline and queues for sync.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/measure/presentation/distance_unit_scope.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/qualified_location.dart';
import '../domain/course_correction.dart';
import '../domain/geometry_layer.dart';
import '../../../data/repositories/course_correction_repository.dart';
import '../../../domain/services/location_service.dart';
import 'correction_submission_bloc.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';
import 'package:vsp_mobile/l10n/app_messages.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Full-screen correction submission form.
///
/// Accessible from the active round "Report Correction" shortcut.
/// Always enabled (offline-aware); shows "Saved offline" confirmation on success.
class CorrectionSubmissionScreen extends StatefulWidget {
  /// Course being corrected.
  final String courseId;

  /// Hole being corrected (optional — null if no active round or issue spans course).
  final String? holeId;

  const CorrectionSubmissionScreen({
    super.key,
    required this.courseId,
    this.holeId,
  });

  @override
  State<CorrectionSubmissionScreen> createState() =>
      _CorrectionSubmissionScreenState();
}

class _CorrectionSubmissionScreenState
    extends State<CorrectionSubmissionScreen> {
  late CorrectionSubmissionBloc _bloc;

  // Form state.
  CorrectionIssueType _selectedIssueType = CorrectionIssueType.pinPosition;

  /// Which geometry layer the golfer says is wrong. Null until they pick one —
  /// there is no sensible default, and guessing would file the report against
  /// the wrong feature.
  GeometryLayer? _selectedLayer;
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  /// Coarsest fix the API will accept (`gpsAccuracyMeters` <= 100).
  static const double _maxUsableAccuracyMeters = 100;

  @override
  void initState() {
    super.initState();
    _bloc = CorrectionSubmissionBloc(
      repository: context.read<CourseCorrectionRepository>(),
      locationService: context.read<LocationService>(),
    );
    _bloc.add(
      LoadCorrectionForm(courseId: widget.courseId, holeId: widget.holeId),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _bloc.close();
    super.dispose();
  }

  // ─── Accuracy color ───────────────────────────────────────────────────────

  Color _accuracyColor(double? accuracy) {
    if (accuracy == null) return Theme.of(context).colorScheme.error; // red — no fix
    if (accuracy <= 5) return Theme.of(context).colorScheme.tertiary; // green
    if (accuracy <= 10) return Theme.of(context).colorScheme.primary; // amber
    return Theme.of(context).colorScheme.error; // red
  }

  String _accuracyLabel(BuildContext context, double? accuracy) {
    final l10n = AppLocalizations.of(context);
    if (accuracy == null) return l10n.correctionAccuracyNoFix;
    // The unit is no longer baked into the string: a golfer who saved yards
    // was told their fix was "Tốt (8 m)" on a screen whose every other
    // distance was in yards. The bands stay in metres — that is what a GPS
    // reports and what "good" is defined against — and only what is shown
    // follows the preference.
    final shown = MeasureUnits.formatTolerance(
      accuracy,
      DistanceUnitScope.watch(context),
    );
    if (accuracy <= 5) return l10n.correctionAccuracyHigh(shown);
    if (accuracy <= 10) return l10n.correctionAccuracyGood(shown);
    if (accuracy <= 20) return l10n.correctionAccuracyModerate(shown);
    return l10n.correctionAccuracyPoor(shown);
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  /// A correction is a claim about a place, so it is only worth sending with a
  /// position good enough to identify the feature. Without that, the report
  /// would be filed at 0,0 or at a fix too coarse for a reviewer to act on.
  String? _blockingReason(BuildContext context, QualifiedLocation? location) {
    final l10n = AppLocalizations.of(context);
    if (_selectedLayer == null) return l10n.msgCorrectionLayerRequired;
    if (location == null) return l10n.correctionNeedsGpsFix;
    final accuracy = location.accuracyMeters;
    // A fix with no reported accuracy is unusable as evidence: the API cannot
    // weigh it and a reviewer cannot tell how far off the claim might be.
    if (accuracy == null) return l10n.correctionNeedsGpsFix;
    if (accuracy > _maxUsableAccuracyMeters) {
      return l10n.correctionAccuracyTooPoor;
    }
    return null;
  }

  Future<void> _submit(QualifiedLocation location) async {
    if (_isSubmitting) return;
    final accuracy = location.accuracyMeters;
    if (accuracy == null) return;

    setState(() => _isSubmitting = true);

    _bloc.add(
      SubmitCorrection(
        issueType: _selectedIssueType,
        layer: _selectedLayer,
        note: _noteController.text.trim(),
        courseId: widget.courseId,
        holeId: widget.holeId,
        reporterLat: location.latitude,
        reporterLng: location.longitude,
        gpsAccuracy: accuracy,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            AppLocalizations.of(context).correctionReportTitle,
            style: TextStyle(color: VspTextTiers.of(context).primary),
          ),
          iconTheme: IconThemeData(color: VspTextTiers.of(context).primary),
        ),
        body: BlocConsumer<CorrectionSubmissionBloc, CorrectionSubmissionState>(
          listener: (context, state) {
            if (state is CorrectionSubmissionSuccess) {
              _isSubmitting = false;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).correctionSavedOffline),
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                );
              Navigator.of(context).pop();
            } else if (state is CorrectionSubmissionFailure) {
              _isSubmitting = false;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(context.tr(state.message)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
            }
          },
          builder: (context, state) {
            final location = state is CorrectionFormReady
                ? state.location
                : null;
            final isLoading =
                state is CorrectionSubmissionLoading || _isSubmitting;
            final blockingReason = _blockingReason(context, location);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Issue type selector ──────────────────────────────────
                  _SectionLabel(label: AppLocalizations.of(context).correctionIssueType),
                  const SizedBox(height: 8),
                  _IssueTypeSelector(
                    selected: _selectedIssueType,
                    onChanged: (type) {
                      setState(() => _selectedIssueType = type);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Geometry layer selector ──────────────────────────────
                  _SectionLabel(label: AppLocalizations.of(context).correctionLayer),
                  const SizedBox(height: 8),
                  _LayerSelector(
                    selected: _selectedLayer,
                    onChanged: (layer) {
                      setState(() => _selectedLayer = layer);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).correctionLayerHint,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Location display ───────────────────────────────────
                  _SectionLabel(label: AppLocalizations.of(context).correctionYourLocation),
                  const SizedBox(height: 8),
                  _LocationCard(
                    location: location,
                    accuracyColor: _accuracyColor(location?.accuracyMeters),
                    accuracyLabel: _accuracyLabel(context, location?.accuracyMeters),
                    capturingLabel:
                        AppLocalizations.of(context).correctionCapturingGps,
                  ),
                  const SizedBox(height: 24),

                  // ── Note field ─────────────────────────────────────────
                  _SectionLabel(label: AppLocalizations.of(context).correctionNote),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLength: 500,
                    maxLines: 4,
                    style: TextStyle(color: VspTextTiers.of(context).primary),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).correctionNoteHint,
                      hintStyle: TextStyle(color: VspTextTiers.of(context).tertiary),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      counterStyle: TextStyle(color: VspTextTiers.of(context).tertiary),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Submit button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading || blockingReason != null
                          ? null
                          : () => _submit(location!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppLocalizations.of(
                                context,
                              ).correctionSubmitCorrection,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      blockingReason ??
                          AppLocalizations.of(
                            context,
                          ).correctionSavesOfflineHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: blockingReason != null
                            ? Theme.of(context).colorScheme.primary
                            : VspTextTiers.of(context).tertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: VspTextTiers.of(context).primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _IssueTypeSelector extends StatelessWidget {
  final CorrectionIssueType selected;
  final ValueChanged<CorrectionIssueType> onChanged;

  const _IssueTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CorrectionIssueType.values.map((type) {
        final isSelected = type == selected;
        return GestureDetector(
          onTap: () => onChanged(type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              type.label,
              style: TextStyle(
                color: isSelected ? Colors.white : VspTextTiers.of(context).primary,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Chips for the five geometry layers a golfer can correct.
///
/// Nothing is selected initially — the golfer must say which layer is wrong,
/// because a report filed against the wrong layer wastes a reviewer's time.
class _LayerSelector extends StatelessWidget {
  final GeometryLayer? selected;
  final ValueChanged<GeometryLayer> onChanged;

  const _LayerSelector({required this.selected, required this.onChanged});

  static String _label(BuildContext context, GeometryLayer layer) {
    final l10n = AppLocalizations.of(context);
    switch (layer) {
      case GeometryLayer.green:
        return l10n.correctionLayerGreen;
      case GeometryLayer.fairway:
        return l10n.correctionLayerFairway;
      case GeometryLayer.bunker:
        return l10n.correctionLayerBunker;
      case GeometryLayer.water:
        return l10n.correctionLayerWater;
      case GeometryLayer.ob:
        return l10n.correctionLayerOb;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: GeometryLayer.values.map((layer) {
        final isSelected = layer == selected;
        final label = _label(context, layer);
        return Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: GestureDetector(
            onTap: () => onChanged(layer),
            child: Container(
              key: ValueKey('correction-layer-${layer.wireValue}'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : VspTextTiers.of(context).primary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final QualifiedLocation? location;
  final Color accuracyColor;
  final String accuracyLabel;
  final String capturingLabel;

  const _LocationCard({
    required this.location,
    required this.accuracyColor,
    required this.accuracyLabel,
    required this.capturingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: accuracyColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (location != null) ...[
                  Text(
                    '${location!.latitude.toStringAsFixed(6)}, ${location!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: VspTextTiers.of(context).primary,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accuracyLabel,
                    style: TextStyle(
                      color: accuracyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Text(
                    capturingLabel,
                    style: TextStyle(
                      color: VspTextTiers.of(context).tertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Accuracy indicator dot.
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accuracyColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
