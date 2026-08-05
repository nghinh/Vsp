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
    final (color, icon, label) = _appearanceFor(syncState);

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

  (Color, IconData, String) _appearanceFor(SyncState state) {
    switch (state) {
      case SyncState.synced:
        return (Colors.green, Icons.check_circle, 'Synced');
      case SyncState.pending:
        return (Colors.amber, Icons.cloud_upload, 'Pending');
      case SyncState.syncing:
        return (Colors.blue, Icons.sync, 'Syncing...');
      case SyncState.failed:
        return (Colors.red, Icons.error, 'Failed');
    }
  }
}
