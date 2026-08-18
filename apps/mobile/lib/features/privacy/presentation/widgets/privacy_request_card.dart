// Privacy Request Card — VSP Mobile App
//
// Card widget showing a privacy request's type, status badge, and date.
// Tap to expand and see details.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import '../../data/privacy_request_dto.dart';

// ─── Privacy Request Card ─────────────────────────────────────────────────────

/// A card displaying a privacy request with type icon, status badge, and date.
class PrivacyRequestCard extends StatelessWidget {
  final PrivacyRequestDTO request;
  final VoidCallback? onTap;

  const PrivacyRequestCard({super.key, required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label:
          '${request.requestType.displayName} request, status ${request.status.displayName}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconBackgroundColor(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForType(request.requestType),
                  color: _iconColor(context),
                  size: VspIconSize.md,
                ),
              ),
              const SizedBox(width: 12),

              // Request info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.requestType.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: VspSpacing.sm),
                        _StatusBadge(status: request.status),
                      ],
                    ),
                    const SizedBox(height: VspSpacing.half),
                    Text(
                      request.formattedRequestedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (request.hasRejectionReason) ...[
                      const SizedBox(height: VspSpacing.xs),
                      Text(
                        'Reason: ${request.rejectionReason}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: (colorScheme.brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.error
                              : VspColorLight.destructive),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron
              const SizedBox(width: VspSpacing.sm),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: VspIconSize.md,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(PrivacyRequestType type) {
    switch (type) {
      case PrivacyRequestType.dataExport:
        return Icons.download;
      case PrivacyRequestType.accountDeletion:
        return Icons.delete_forever;
      case PrivacyRequestType.roundDeletion:
        return Icons.golf_course;
    }
  }

  Color _iconBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = colorScheme.brightness;

    switch (request.requestType) {
      case PrivacyRequestType.dataExport:
        return (brightness == Brightness.dark
                ? Theme.of(context).colorScheme.tertiary
                : VspColorLight.accent)
            .withOpacity(0.15);
      case PrivacyRequestType.accountDeletion:
        return (brightness == Brightness.dark
                ? Theme.of(context).colorScheme.error
                : VspColorLight.destructive)
            .withOpacity(0.15);
      case PrivacyRequestType.roundDeletion:
        return colorScheme.primary.withOpacity(0.15);
    }
  }

  Color _iconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = colorScheme.brightness;

    switch (request.requestType) {
      case PrivacyRequestType.dataExport:
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.tertiary
            : VspColorLight.accent);
      case PrivacyRequestType.accountDeletion:
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.error
            : VspColorLight.destructive);
      case PrivacyRequestType.roundDeletion:
        return colorScheme.primary;
    }
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final PrivacyRequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VspSpacing.sm,
        vertical: VspSpacing.half,
      ),
      decoration: BoxDecoration(
        color: _badgeColor(context).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _badgeColor(context).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForStatus(status), size: 12, color: _badgeColor(context)),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _badgeColor(context),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForStatus(PrivacyRequestStatus status) {
    switch (status) {
      case PrivacyRequestStatus.pending:
        return Icons.schedule;
      case PrivacyRequestStatus.processing:
        return Icons.sync;
      case PrivacyRequestStatus.completed:
        return Icons.check_circle;
      case PrivacyRequestStatus.rejected:
        return Icons.cancel;
    }
  }

  Color _badgeColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = colorScheme.brightness;

    switch (status) {
      case PrivacyRequestStatus.pending:
        // Amber/warning for pending
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.secondary
            : VspColorLight.secondary);
      case PrivacyRequestStatus.processing:
        // Blue for processing
        return const Color(0xFF3B82F6); // syncPending blue
      case PrivacyRequestStatus.completed:
        // Green/accent for completed
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.tertiary
            : VspColorLight.accent);
      case PrivacyRequestStatus.rejected:
        // Red/destructive for rejected
        return (brightness == Brightness.dark
            ? Theme.of(context).colorScheme.error
            : VspColorLight.destructive);
    }
  }
}

// ─── Semantic Token ───────────────────────────────────────────────────────────

enum _SemanticToken { destructive, online, warning }
