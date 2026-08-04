// CorrectionListScreen — VSP Mobile App
//
// "My Corrections" list screen — shows all corrections submitted by the
// current user with their sync state (pending/submitted/accepted/rejected).
//
// Per Story 9.1 Slice 4: My corrections list UI.
//
// Entry point: accessible from "More" bottom nav or profile section.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/course_correction.dart';
import '../../../data/repositories/course_correction_repository.dart';
import 'correction_list_bloc.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// "My Corrections" list screen.
class CorrectionListScreen extends StatefulWidget {
  /// Optional course ID to filter corrections by course.
  final String? courseId;

  const CorrectionListScreen({super.key, this.courseId});

  @override
  State<CorrectionListScreen> createState() => _CorrectionListScreenState();
}

class _CorrectionListScreenState extends State<CorrectionListScreen> {
  late CorrectionListBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = CorrectionListBloc(
      repository: context.read<CourseCorrectionRepository>(),
    );
    _bloc.add(LoadCorrections(courseId: widget.courseId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  // ─── Sync state chip ────────────────────────────────────────────────────

  Widget _syncStateChip(CorrectionSyncState state) {
    final (color, label) = switch (state) {
      CorrectionSyncState.pending => (const Color(0xFFEA580C), 'Pending'),
      CorrectionSyncState.submitted => (const Color(0xFF2563EB), 'Submitted'),
      CorrectionSyncState.accepted => (const Color(0xFF16A34A), 'Accepted'),
      CorrectionSyncState.rejected => (const Color(0xFFDC2626), 'Rejected'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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
            'My Corrections',
            style: TextStyle(color: Color(0xFFF8FAFC)),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
        ),
        body: BlocBuilder<CorrectionListBloc, CorrectionListState>(
          builder: (context, state) {
            if (state is CorrectionListLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFEA580C)),
              );
            }

            if (state is CorrectionListError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(color: Color(0xFFDC2626)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _bloc.add(const RefreshCorrections()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is CorrectionListEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 64,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No corrections submitted yet',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Report an issue from the active round\nto see it listed here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final corrections = (state as CorrectionListLoaded).corrections;

            return RefreshIndicator(
              onRefresh: () async {
                _bloc.add(const RefreshCorrections());
                // Wait for the state to change.
                await _bloc.stream.firstWhere(
                  (s) => s is! CorrectionListLoading,
                );
              },
              color: const Color(0xFFEA580C),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: corrections.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Color(0xFF334155), height: 1),
                itemBuilder: (context, index) {
                  final c = corrections[index];
                  return _CorrectionListItem(
                    correction: c,
                    syncStateChip: _syncStateChip(c.syncState),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── List Item ────────────────────────────────────────────────────────────────

class _CorrectionListItem extends StatelessWidget {
  final CourseCorrection correction;
  final Widget syncStateChip;

  const _CorrectionListItem({
    required this.correction,
    required this.syncStateChip,
  });

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Issue type icon.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.flag_outlined,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Content.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        correction.issueType.label,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    syncStateChip,
                  ],
                ),
                if (correction.note != null && correction.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    correction.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${correction.reporterLat.toStringAsFixed(4)}, ${correction.reporterLng.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      correction.accuracyLabel,
                      style: TextStyle(
                        color: correction.hasAcceptableAccuracy
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(correction.submittedAt),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
