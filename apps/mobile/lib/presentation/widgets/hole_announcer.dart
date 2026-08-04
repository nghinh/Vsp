// HoleAnnouncer — VSP Mobile App
//
// Story 6.2 — Wave F: Observability & Accessibility
//
// Screen reader announcer for hole changes.
// Announces hole transitions to visually impaired users.
//
// Accessibility (per UX spec §10):
// - Screen reader announces hole changes
// - Semantic labels on all interactive elements
// - Non-color-only indicators

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Mixin for widgets that need to announce hole changes to screen readers.
///
/// Usage:
/// ```dart
/// class MyWidget with HoleAnnouncerMixin {
///   void _onHoleChanged(int holeNumber) {
///     announceHoleChange(context, holeNumber);
///   }
/// }
mixin HoleAnnouncerMixin {
  /// Announce a hole change to screen readers.
  ///
  /// Uses SemanticsService.announce() for live region announcements.
  void announceHoleChange(BuildContext context, int holeNumber) {
    SemanticsService.announce('Now on hole $holeNumber', TextDirection.ltr);
  }

  /// Announce a hole transition suggestion to screen readers.
  void announceHoleSuggestion(
    BuildContext context,
    int suggestedHole,
    String confidence,
  ) {
    SemanticsService.announce(
      'Suggested hole $suggestedHole. $confidence confidence. '
      'Confirmation required.',
      TextDirection.ltr,
    );
  }

  /// Announce that auto-switch was blocked due to low confidence.
  void announceAutoSwitchBlocked(BuildContext context, String reason) {
    SemanticsService.announce(
      'Auto hole switch blocked. $reason. Please select manually.',
      TextDirection.ltr,
    );
  }

  /// Announce manual hole selection to screen readers.
  void announceManualSelection(BuildContext context, int holeNumber) {
    SemanticsService.announce(
      'Manually selected hole $holeNumber',
      TextDirection.ltr,
    );
  }

  /// Announce that no facility was found nearby.
  void announceNoFacilityFound(BuildContext context) {
    SemanticsService.announce(
      'No golf facility found nearby. '
      'You may be off-course or need to download course data.',
      TextDirection.ltr,
    );
  }

  /// Announce GPS quality issue.
  void announceGpsIssue(BuildContext context, String issue) {
    SemanticsService.announce('GPS issue: $issue', TextDirection.ltr);
  }
}

/// Widget that wraps a child and announces detection events.
///
/// Place this widget above the hole map to ensure announcements
/// are made when detection state changes.
class HoleAnnouncer extends StatefulWidget {
  /// Current hole number.
  final int? holeNumber;

  /// Whether a switch is pending confirmation.
  final bool pendingSwitch;

  /// Suggested hole number for pending switch.
  final int? suggestedHoleNumber;

  /// Confidence level.
  final String? confidenceLabel;

  /// Whether auto-switch is blocked.
  final bool autoSwitchBlocked;

  /// Reason for blocking (if applicable).
  final String? blockedReason;

  /// Child widget to wrap.
  final Widget child;

  const HoleAnnouncer({
    super.key,
    this.holeNumber,
    this.pendingSwitch = false,
    this.suggestedHoleNumber,
    this.confidenceLabel,
    this.autoSwitchBlocked = false,
    this.blockedReason,
    required this.child,
  });

  @override
  State<HoleAnnouncer> createState() => _HoleAnnouncerState();
}

class _HoleAnnouncerState extends State<HoleAnnouncer> with HoleAnnouncerMixin {
  int? _previousHoleNumber;

  @override
  void didUpdateWidget(HoleAnnouncer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Announce hole change
    if (widget.holeNumber != null && widget.holeNumber != _previousHoleNumber) {
      _previousHoleNumber = widget.holeNumber;
      announceHoleChange(context, widget.holeNumber!);
    }

    // Announce pending switch
    if (widget.pendingSwitch &&
        !oldWidget.pendingSwitch &&
        widget.suggestedHoleNumber != null) {
      announceHoleSuggestion(
        context,
        widget.suggestedHoleNumber!,
        widget.confidenceLabel ?? 'low',
      );
    }

    // Announce auto-switch blocked
    if (widget.autoSwitchBlocked &&
        !oldWidget.autoSwitchBlocked &&
        widget.blockedReason != null) {
      announceAutoSwitchBlocked(context, widget.blockedReason!);
    }
  }

  @override
  void initState() {
    super.initState();
    _previousHoleNumber = widget.holeNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.holeNumber != null
          ? 'Current hole: ${widget.holeNumber}'
          : 'Hole detection not available',
      child: widget.child,
    );
  }
}
