// Accessibility Wrapper — VSP Watch Apple App
//
// Accessibility support for VoiceOver and Dynamic Type.
// AC-7: Accessibility requirements met (VoiceOver labels, Dynamic Type).
//
// Story 10.1 — Slice 5: Crown/Touch & Accessibility

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/watch_theme.dart';

/// Accessibility settings for the watch app.
class WatchAccessibilitySettings {
  final bool isVoiceOverRunning;
  final double textScaleFactor;
  final bool reduceMotion;

  const WatchAccessibilitySettings({
    this.isVoiceOverRunning = false,
    this.textScaleFactor = 1.0,
    this.reduceMotion = false,
  });
}

/// Mixin for widgets that need accessibility support.
mixin AccessibilityMixin<T extends StatefulWidget> on State<T> {
  WatchAccessibilitySettings _settings = const WatchAccessibilitySettings();

  WatchAccessibilitySettings get accessibilitySettings => _settings;

  @override
  void initState() {
    super.initState();
    _updateAccessibilitySettings();
  }

  void _updateAccessibilitySettings() {
    final mediaQuery = MediaQuery.of(context);

    _settings = WatchAccessibilitySettings(
      isVoiceOverRunning: mediaQuery.accessibilityFeatures.accessibleNavigation,
      textScaleFactor: mediaQuery.textScaleFactor,
      reduceMotion: mediaQuery.accessibilityFeatures.reduceMotion,
    );
  }

  /// Apply accessibility text style if needed.
  TextStyle? maybeScaledTextStyle(
    TextStyle? style, {
    double minScale = 0.8,
    double maxScale = 1.5,
  }) {
    if (style == null) return null;

    final scale = _settings.textScaleFactor.clamp(minScale, maxScale);

    // For very small text, ensure minimum readable size
    if (style.fontSize != null) {
      final scaledSize = style.fontSize! * scale;
      // Minimum readable size for watch (10pt)
      final finalSize = scaledSize < 10 ? 10.0 : scaledSize;
      return style.copyWith(fontSize: finalSize);
    }

    return style;
  }

  /// Get animation duration respecting reduced motion.
  Duration maybeReducedDuration(Duration normalDuration) {
    if (_settings.reduceMotion) {
      return Duration.zero;
    }
    return normalDuration;
  }

  /// Get animation curve respecting reduced motion.
  Curve maybeReducedCurve(Curve normalCurve) {
    if (_settings.reduceMotion) {
      return Curves.linear;
    }
    return normalCurve;
  }
}

/// Wrapper for accessibility-aware watch widgets.
class AccessibilityWrapper extends StatefulWidget {
  final Widget child;
  final Widget Function(
    BuildContext context,
    WatchAccessibilitySettings settings,
  ) builder;

  const AccessibilityWrapper({
    super.key,
    required this.child,
    required this.builder,
  });

  @override
  State<AccessibilityWrapper> createState() => _AccessibilityWrapperState();
}

class _AccessibilityWrapperState extends State<AccessibilityWrapper> {
  late WatchAccessibilitySettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _computeSettings();
  }

  WatchAccessibilitySettings _computeSettings() {
    final mediaQuery = MediaQuery.of(context);
    return WatchAccessibilitySettings(
      isVoiceOverRunning:
          mediaQuery.accessibilityFeatures.accessibleNavigation,
      textScaleFactor: mediaQuery.textScaleFactor,
      reduceMotion: mediaQuery.accessibilityFeatures.reduceMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _settings);
  }
}

/// Accessibility helper for semantic labels.
class SemanticLabel {
  /// Generate a distance semantic label.
  static String distance({
    required String label,
    required String formattedDistance,
    double? confidence,
  }) {
    final parts = <String>['$label: $formattedDistance'];
    if (confidence != null) {
      parts.add('confidence ${(confidence * 100).round()} percent');
    }
    return parts.join(', ');
  }

  /// Generate a score semantic label.
  static String score({
    required int? strokes,
    required int? putts,
    required int? penalties,
  }) {
    final parts = <String>[];

    if (strokes != null) {
      parts.add('$strokes strokes');
    }
    if (putts != null) {
      parts.add('$putts putts');
    }
    if (penalties != null && penalties > 0) {
      parts.add('$penalties penalty');
    }

    return parts.isEmpty ? 'No score entered' : parts.join(', ');
  }

  /// Generate a hole navigation semantic label.
  static String holeNavigation({
    required int currentHole,
    required int totalHoles,
    int? par,
  }) {
    final parts = <String>[
      'Hole $currentHole of $totalHoles',
    ];
    if (par != null) {
      parts.add('par $par');
    }
    return parts.join(', ');
  }

  /// Generate a sync status semantic label.
  static String syncStatus({
    required String status,
    int? pendingCount,
  }) {
    switch (status) {
      case 'synced':
        return 'All data synced';
      case 'pending':
        return pendingCount != null && pendingCount > 0
            ? '$pendingCount items pending sync'
            : 'Sync pending';
      case 'local':
        return 'Saved locally, not yet synced';
      case 'conflict':
        return 'Sync conflict detected';
      default:
        return 'Unknown sync status';
    }
  }
}

/// Large text widget that respects Dynamic Type.
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final scaleFactor = mediaQuery.textScaleFactor.clamp(0.8, 1.5);

    TextStyle effectiveStyle = style ?? const TextStyle();

    if (effectiveStyle.fontSize != null) {
      final scaledSize = effectiveStyle.fontSize! * scaleFactor;
      // Ensure minimum readable size for watch
      effectiveStyle = effectiveStyle.copyWith(
        fontSize: scaledSize < 10 ? 10.0 : scaledSize,
      );
    }

    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Button with accessibility support (large tap target, proper labels).
class AccessibleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;
  final bool enabled;

  const AccessibleButton({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 44, // 44pt minimum touch target
            minHeight: 44,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Animated widget that respects reduced motion settings.
class ReducedMotionAnimatedSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve? switchInCurve;
  final Curve? switchOutCurve;

  const ReducedMotionAnimatedSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration,
    this.switchInCurve,
    this.switchOutCurve,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.of(context).accessibilityFeatures.reduceMotion;

    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : duration,
      reverseDuration: reduceMotion ? Duration.zero : reverseDuration,
      switchInCurve: reduceMotion ? Curves.linear : (switchInCurve ?? Curves.easeInOut),
      switchOutCurve: reduceMotion ? Curves.linear : (switchOutCurve ?? Curves.easeInOut),
      child: child,
    );
  }
}

/// Progress indicator that respects reduced motion.
class ReducedMotionProgressIndicator extends StatelessWidget {
  final double? value;
  final double size;

  const ReducedMotionProgressIndicator({
    super.key,
    this.value,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.of(context).accessibilityFeatures.reduceMotion;

    if (reduceMotion) {
      return value != null
          ? Text(
              '${(value! * 100).round()}%',
              style: const TextStyle(fontSize: 12),
            )
          : const CupertinoActivityIndicator();
    }

    return SizedBox(
      width: size,
      height: size,
      child: value != null
          ? CircularProgressIndicator(value: value)
          : const CupertinoActivityIndicator(),
    );
  }
}
