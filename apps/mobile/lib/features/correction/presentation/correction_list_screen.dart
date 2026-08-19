// CorrectionListScreen — VSP Mobile App
//
// "My Corrections" list screen — shows all corrections submitted by the
// current user with their sync state (pending/submitted/accepted/rejected).
//
// Per Story 9.1 Slice 4: My corrections list UI.
//
// Entry point: accessible from "More" bottom nav or profile section.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/course_correction.dart';
import '../../../data/repositories/course_correction_repository.dart';
import 'correction_list_bloc.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

/// "My Corrections" list screen.
class CorrectionListScreen extends StatefulWidget {
  /// Optional course ID to filter corrections by course.
  final String? courseId;

  /// Where the reports are read from.
  ///
  /// Optional, and it has to be: this screen is opened from two places that do
  /// not resemble each other. Inside a round it sits under a
  /// `RepositoryProvider<CourseCorrectionRepository>` that the round builds;
  /// from the More menu it is pushed on its own, with nothing above it — and
  /// `context.read` on a provider that is not there does not degrade, it
  /// throws:
  ///
  ///     Could not find the correct Provider<CourseCorrectionRepository>
  ///     above this CorrectionListScreen Widget
  ///
  /// So "Báo lỗi dữ liệu của tôi" opened onto a crash for every golfer who was
  /// not in the middle of a round. Found by the screen-by-screen sweep; no
  /// test had ever opened this screen from the menu it lives in.
  final CourseCorrectionRepository? repository;

  const CorrectionListScreen({super.key, this.courseId, this.repository});

  @override
  State<CorrectionListScreen> createState() => _CorrectionListScreenState();
}

class _CorrectionListScreenState extends State<CorrectionListScreen> {
  late CorrectionListBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = CorrectionListBloc(repository: _resolveRepository());
    _bloc.add(LoadCorrections(courseId: widget.courseId));
  }

  /// The injected repository, the one a round provides, or a fresh one.
  ///
  /// In that order, and the last step is the point: a screen reachable from a
  /// menu cannot depend on a provider that only a round installs.
  CourseCorrectionRepository _resolveRepository() {
    final given = widget.repository;
    if (given != null) return given;
    try {
      return context.read<CourseCorrectionRepository>();
    } catch (_) {
      return CourseCorrectionRepositoryImpl();
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  // ─── Sync state chip ────────────────────────────────────────────────────

  Widget _syncStateChip(CorrectionSyncState state) {
    final (color, label) = switch (state) {
      CorrectionSyncState.pending => (Theme.of(context).colorScheme.primary, 'Pending'),
      CorrectionSyncState.submitted => (const Color(0xFF2563EB), 'Submitted'),
      CorrectionSyncState.accepted => (Theme.of(context).colorScheme.tertiary, 'Accepted'),
      CorrectionSyncState.rejected => (Theme.of(context).colorScheme.error, 'Rejected'),
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
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            AppLocalizations.of(context).correctionsMine,
            style: TextStyle(color: VspTextTiers.of(context).primary),
          ),
          iconTheme: IconThemeData(color: VspTextTiers.of(context).primary),
        ),
        body: BlocBuilder<CorrectionListBloc, CorrectionListState>(
          builder: (context, state) {
            // Initial is the first frame, before the bloc has processed the
            // load this screen queued in initState. It is not "no data" — it
            // is "not yet" — so it draws the same spinner as loading.
            if (state is CorrectionListInitial ||
                state is CorrectionListLoading) {
              return Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              );
            }

            if (state is CorrectionListError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _bloc.add(const RefreshCorrections()),
                      child: Text(AppLocalizations.of(context).commonRetry),
                    ),
                  ],
                ),
              );
            }

            if (state is CorrectionListEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 64,
                      color: VspTextTiers.of(context).tertiary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).correctionsNoneYet,
                      style: TextStyle(
                        color: VspTextTiers.of(context).primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Report an issue from the active round\nto see it listed here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VspTextTiers.of(context).tertiary, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            // Not a cast. Every state above is handled by name, and this used
            // to assume whatever was left had to be Loaded — which threw on
            // the first frame, when the state is Initial:
            //
            //     type 'CorrectionListInitial' is not a subtype of type
            //     'CorrectionListLoaded' in type cast
            //
            // A state added later would land here the same way, so the guard
            // stays even though Initial is handled above.
            if (state is! CorrectionListLoaded) {
              return Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              );
            }
            final corrections = state.corrections;

            return RefreshIndicator(
              onRefresh: () async {
                _bloc.add(const RefreshCorrections());
                // Wait for the state to change.
                await _bloc.stream.firstWhere(
                  (s) => s is! CorrectionListLoading,
                );
              },
              color: Theme.of(context).colorScheme.primary,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: corrections.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
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
      color: Theme.of(context).colorScheme.inverseSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Issue type icon.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.flag_outlined,
              color: Theme.of(context).colorScheme.primary,
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
                        style: TextStyle(
                          color: VspTextTiers.of(context).primary,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: VspTextTiers.of(context).tertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${correction.reporterLat.toStringAsFixed(4)}, ${correction.reporterLng.toStringAsFixed(4)}',
                      style: TextStyle(
                        color: VspTextTiers.of(context).tertiary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      correction.accuracyLabel,
                      style: TextStyle(
                        color: correction.hasAcceptableAccuracy
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.error,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(correction.submittedAt),
                  style: TextStyle(
                    color: VspTextTiers.of(context).tertiary,
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
