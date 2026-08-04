// SessionCard — VSP Mobile App
//
// A card widget displaying a single session's device info, last used time,
// and an optional revoke button.
//
// Accessibility per UX spec §10:
// - Screen reader labels for session info and revoke button
// - 44pt minimum touch target on revoke button
// - Non-color-only status indicators

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../data/auth_dto.dart';

/// Card widget for a single session row in the session management screen.
class SessionCard extends StatelessWidget {
  /// The session info to display.
  final SessionInfo session;

  /// Callback when the revoke button is pressed.
  final VoidCallback? onRevoke;

  /// Whether this card is for the current session (shows "This device" label).
  final bool isCurrentSession;

  const SessionCard({
    super.key,
    required this.session,
    this.onRevoke,
    this.isCurrentSession = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return VspCard(
      semanticLabel: isCurrentSession
          ? 'Current session on ${session.deviceLabel}, active ${session.createdAtLabel}'
          : 'Session on ${session.deviceLabel}, active ${session.createdAtLabel}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Device Icon ────────────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCurrentSession
                  ? colorScheme.primary.withOpacity(0.1)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _deviceIcon(session.userAgent ?? ''),
              color: isCurrentSession
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // ─── Session Info ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device label + current session badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.deviceLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: VspFontWeight.medium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentSession) ...[
                      const SizedBox(width: VspSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VspSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'This device',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: VspSpacing.half),

                // Last active / created time
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: VspSpacing.half),
                    Text(
                      'Active ${session.createdAtLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // IP address if available
                if (session.ipAddress != null &&
                    session.ipAddress!.isNotEmpty) ...[
                  const SizedBox(height: VspSpacing.half),
                  Row(
                    children: [
                      Icon(
                        Icons.language,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: VspSpacing.half),
                      Text(
                        session.ipAddress!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ─── Revoke Button ─────────────────────────────────────────────────
          if (!isCurrentSession && onRevoke != null)
            Semantics(
              label: 'Revoke session on ${session.deviceLabel}',
              button: true,
              child: IconButton(
                onPressed: onRevoke,
                icon: Icon(Icons.logout, color: colorScheme.error, size: 20),
                tooltip: 'Revoke session',
                style: IconButton.styleFrom(
                  minimumSize: const Size(
                    VspSpacingSemantic.touchTargetMin,
                    VspSpacingSemantic.touchTargetMin,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Determines the appropriate device icon based on user agent string.
  IconData _deviceIcon(String userAgent) {
    final ua = userAgent.toLowerCase();
    if (ua.contains('iphone') || ua.contains('ios')) {
      return Icons.phone_iphone;
    } else if (ua.contains('ipad') || ua.contains('tablet')) {
      return Icons.tablet_mac;
    } else if (ua.contains('android')) {
      return Icons.phone_android;
    } else if (ua.contains('macintosh') || ua.contains('mac os')) {
      return Icons.laptop_mac;
    } else if (ua.contains('windows')) {
      return Icons.laptop_windows;
    } else if (ua.contains('linux')) {
      return Icons.computer;
    }
    return Icons.devices;
  }
}
