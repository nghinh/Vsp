// CorrectionSubmissionScreen — VSP Mobile App
//
// Full-screen form for submitting a course-data correction.
//
// Per Story 9.1 Slice 3: Submission form UI.
//
// AC fields: issue type, course, hole, location, accuracy, timestamp,
// optional note. Saves offline and queues for sync.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/qualified_location.dart';
import '../domain/course_correction.dart';
import '../../../data/repositories/course_correction_repository.dart';
import '../../../domain/services/location_service.dart';
import 'correction_submission_bloc.dart';

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
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

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
    if (accuracy == null) return const Color(0xFFDC2626); // red — no fix
    if (accuracy <= 5) return const Color(0xFF16A34A); // green
    if (accuracy <= 10) return const Color(0xFFEA580C); // amber
    return const Color(0xFFDC2626); // red
  }

  String _accuracyLabel(double? accuracy) {
    if (accuracy == null) return 'No GPS fix';
    if (accuracy <= 5) return 'High ($accuracy m)';
    if (accuracy <= 10) return 'Good ($accuracy m)';
    if (accuracy <= 20) return 'Moderate ($accuracy m)';
    return 'Poor ($accuracy m)';
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit(QualifiedLocation? location) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    _bloc.add(
      SubmitCorrection(
        issueType: _selectedIssueType,
        note: _noteController.text.trim(),
        courseId: widget.courseId,
        holeId: widget.holeId,
        reporterLat: location?.latitude ?? 0,
        reporterLng: location?.longitude ?? 0,
        gpsAccuracy: location?.accuracyMeters ?? -1,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Report Correction',
            style: TextStyle(color: Color(0xFFF8FAFC)),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
        ),
        body: BlocConsumer<CorrectionSubmissionBloc, CorrectionSubmissionState>(
          listener: (context, state) {
            if (state is CorrectionSubmissionSuccess) {
              _isSubmitting = false;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Correction saved offline'),
                    backgroundColor: Color(0xFF16A34A),
                  ),
                );
              Navigator.of(context).pop();
            } else if (state is CorrectionSubmissionFailure) {
              _isSubmitting = false;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: const Color(0xFFDC2626),
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Issue type selector ──────────────────────────────────
                  _SectionLabel(label: 'Issue Type'),
                  const SizedBox(height: 8),
                  _IssueTypeSelector(
                    selected: _selectedIssueType,
                    onChanged: (type) {
                      setState(() => _selectedIssueType = type);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Location display ───────────────────────────────────
                  _SectionLabel(label: 'Your Location'),
                  const SizedBox(height: 8),
                  _LocationCard(
                    location: location,
                    accuracyColor: _accuracyColor(location?.accuracyMeters),
                    accuracyLabel: _accuracyLabel(location?.accuracyMeters),
                  ),
                  const SizedBox(height: 24),

                  // ── Note field ─────────────────────────────────────────
                  _SectionLabel(label: 'Note (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLength: 500,
                    maxLines: 4,
                    style: const TextStyle(color: Color(0xFFF8FAFC)),
                    decoration: InputDecoration(
                      hintText: 'Describe the issue…',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFEA580C)),
                      ),
                      counterStyle: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Submit button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () => _submit(location),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
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
                          : const Text(
                              'Submit Correction',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Saves offline and syncs when connected',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
      style: const TextStyle(
        color: Color(0xFFF8FAFC),
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
                  ? const Color(0xFFEA580C)
                  : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFEA580C)
                    : const Color(0xFF334155),
              ),
            ),
            child: Text(
              type.label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
                fontSize: 13,
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

  const _LocationCard({
    required this.location,
    required this.accuracyColor,
    required this.accuracyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
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
                    style: const TextStyle(
                      color: Color(0xFFF8FAFC),
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
                  const Text(
                    'Capturing GPS…',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
