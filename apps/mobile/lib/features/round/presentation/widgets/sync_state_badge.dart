// SyncStateBadge Widget — VSP Mobile App
//
// Visual badge showing sync state with icon + color + label.
// Per Story 5.5 Slice 3: AC-2 sync state indicator with color + icon (not color alone).
//
// UX-DR principles: non-color-only indicator with icon + label.

import 'package:flutter/material.dart';

import '../../domain/sync_state.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

/// Badge widget displaying sync state with icon and label.
class SyncStateBadge extends StatelessWidget {
  final SyncState syncState;

  const SyncStateBadge({super.key, required this.syncState});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _appearanceFor(context, syncState);

    return Semantics(
      label: AppLocalizations.of(context).syncStatusLabel(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData, String) _appearanceFor(
    BuildContext context,
    SyncState state,
  ) {
    // Every label from l10n. These were 'Synced', 'Pending', 'Syncing...' and
    // 'Failed' — English, on a badge a Vietnamese golfer sees on the scorecard
    // and on the summary of every round they play. The strings already existed
    // in both .arb files and nothing was reading them.
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case SyncState.synced:
        return (scheme.tertiary, Icons.check_circle, l10n.syncSaved);
      case SyncState.pending:
        return (scheme.secondary, Icons.cloud_upload, l10n.syncPending);
      case SyncState.syncing:
        // Blue is progress and has no role in the scheme; it is the one
        // Material colour on this badge with nothing to map to.
        return (Colors.blue, Icons.sync, l10n.syncSyncing);
      case SyncState.failed:
        return (scheme.error, Icons.error, l10n.syncFailed);
    }
  }
}
