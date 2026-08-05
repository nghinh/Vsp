// Crown Input Handler — VSP Watch Apple App
//
// Digital crown input processing for watch navigation.
// AC-7: Crown/touch controls meet platform accessibility and battery requirements.
//
// Story 10.1 — Slice 5: Crown/Touch & Accessibility

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Crown input event types.
enum CrownEventType {
  scrollUp,
  scrollDown,
  tap,
  doubleTap,
  longPress,
}

/// Crown input event with direction and magnitude.
class CrownEvent extends Equatable {
  final CrownEventType type;
  final double delta; // Scroll amount (negative = up, positive = down)
  final DateTime timestamp;

  const CrownEvent({
    required this.type,
    this.delta = 0,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, delta, timestamp];
}

/// Crown input handler for watch navigation.
///
/// Processes digital crown events and maps them to navigation actions:
/// - Scroll up/down: navigate holes or adjust target
/// - Tap: select/confirm
/// - Double tap: quick score entry (shortcut)
/// - Long press: main menu
class CrownInputHandler {
  /// Minimum delta to register as a scroll event.
  static const double scrollThreshold = 0.5;

  /// Maximum time between taps for double-tap detection.
  static const Duration doubleTapWindow = Duration(milliseconds: 300);

  DateTime? _lastTapTime;
  double _scrollAccumulator = 0;

  /// Process raw crown data from platform channel.
  CrownEvent? processCrownData(double delta) {
    _scrollAccumulator += delta;

    // Check for tap events (small delta with no accumulated movement)
    if (delta.abs() < 0.1) {
      return _handleTap();
    }

    // Accumulate scroll events
    if (_scrollAccumulator.abs() >= scrollThreshold) {
      final direction = _scrollAccumulator > 0
          ? CrownEventType.scrollDown
          : CrownEventType.scrollUp;
      _scrollAccumulator = 0;
      return CrownEvent(
        type: direction,
        delta: delta,
        timestamp: DateTime.now(),
      );
    }

    return null;
  }

  /// Handle tap detection.
  CrownEvent? _handleTap() {
    final now = DateTime.now();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < doubleTapWindow) {
      _lastTapTime = null;
      return CrownEvent(
        type: CrownEventType.doubleTap,
        timestamp: now,
      );
    }

    _lastTapTime = now;
    return CrownEvent(
      type: CrownEventType.tap,
      timestamp: now,
    );
  }

  /// Reset state.
  void reset() {
    _lastTapTime = null;
    _scrollAccumulator = 0;
  }
}

/// Action mapping from crown events to app actions.
enum CrownAction {
  nextHole,
  previousHole,
  selectConfirm,
  quickScore,
  mainMenu,
  adjustTarget,
}

/// Maps crown events to app actions based on current context.
class CrownActionMapper {
  /// Current navigation context.
  final CrownContext context;

  CrownActionMapper({required this.context});

  CrownAction mapEvent(CrownEvent event) {
    switch (event.type) {
      case CrownEventType.scrollDown:
        return _mapScroll(CrownEventType.scrollDown);
      case CrownEventType.scrollUp:
        return _mapScroll(CrownEventType.scrollUp);
      case CrownEventType.tap:
        return CrownAction.selectConfirm;
      case CrownEventType.doubleTap:
        return CrownAction.quickScore;
      case CrownEventType.longPress:
        return CrownAction.mainMenu;
    }
  }

  CrownAction _mapScroll(CrownEventType scrollType) {
    switch (context) {
      case CrownContext.distancePanel:
        // Scroll holes
        return scrollType == CrownEventType.scrollDown
            ? CrownAction.nextHole
            : CrownAction.previousHole;
      case CrownContext.scoreEntry:
        // Adjust score
        return scrollType == CrownEventType.scrollDown
            ? CrownAction.adjustTarget
            : CrownAction.adjustTarget; // Same action, just direction
      case CrownContext.menu:
        // Navigate menu
        return scrollType == CrownEventType.scrollDown
            ? CrownAction.nextHole
            : CrownAction.previousHole;
    }
  }
}

/// Context for crown action mapping.
enum CrownContext {
  distancePanel,
  scoreEntry,
  menu,
}

/// Watch-specific crown input widget using Digital crown.
///
/// Wraps a child and handles crown input for navigation.
class CrownInputWidget extends StatefulWidget {
  final Widget child;
  final CrownContext context;
  final ValueChanged<CrownAction>? onAction;
  final bool enabled;

  const CrownInputWidget({
    super.key,
    required this.child,
    this.context = CrownContext.distancePanel,
    this.onAction,
    this.enabled = true,
  });

  @override
  State<CrownInputWidget> createState() => _CrownInputWidgetState();
}

class _CrownInputWidgetState extends State<CrownInputWidget> {
  final CrownInputHandler _handler = CrownInputHandler();
  late CrownActionMapper _mapper;

  @override
  void initState() {
    super.initState();
    _mapper = CrownActionMapper(context: widget.context);
  }

  @override
  void didUpdateWidget(CrownInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.context != widget.context) {
      _mapper = CrownActionMapper(context: widget.context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Focus widget to capture crown events
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    // Map Flutter key events to crown events.
    //
    // On watchOS the physical Digital Crown surfaces to Flutter as directional
    // scroll/key events; we translate those here so navigation works with the
    // crown, a rotary encoder, or a keyboard. A dedicated `DigitalCrown`
    // platform channel can later feed `CrownInputHandler.processCrownData`
    // directly for continuous rotation without changing this mapping.
    CrownEvent? crownEvent;

    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.pageUp) {
        crownEvent = _handler.processCrownData(-1.0);
      } else if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.pageDown) {
        crownEvent = _handler.processCrownData(1.0);
      } else if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.space) {
        crownEvent = CrownEvent(
          type: CrownEventType.tap,
          timestamp: DateTime.now(),
        );
      } else if (key == LogicalKeyboardKey.goBack ||
          key == LogicalKeyboardKey.escape) {
        crownEvent = CrownEvent(
          type: CrownEventType.longPress,
          timestamp: DateTime.now(),
        );
      }
    }

    if (crownEvent != null) {
      final action = _mapper.mapEvent(crownEvent);
      widget.onAction?.call(action);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
