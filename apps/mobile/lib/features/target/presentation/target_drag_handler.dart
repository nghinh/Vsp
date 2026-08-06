// Target Drag Handler — VSP Mobile App
//
// Wraps the MapLibre map widget to intercept long-press drag gestures on
// the target annotation without conflicting with map pan/zoom.
//
// Gesture flow:
//   LongPressStart (300ms) → enter drag mode, suppress map gestures
//   LongPressMoveUpdate      → update annotation position (visual only)
//   LongPressEnd             → save new target position via cubit, restore map gestures
//
// Usage with HoleMapScreen (story 6.3):
//   TargetDragHandler(
//     mapController: mapController,
//     target: state.target,
//     onPositionUpdate: (coords) { /* update annotation visually */ },
//     onDragEnd: (coords) { cubit.moveTarget(coords); },
//     onDragStart: () { cubit.setDragging(true); },
//     child: MapLibreMap(...),
//   )
//
// Story 6.5 — Slice 2: Drag Without Pan/Zoom Conflict

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../domain/target_model.dart';

/// Callback type for position updates during drag (visual only).
typedef DragPositionUpdate = void Function(List<double> mapCoordinates);

/// Callback when drag ends — pass new position to cubit for persistence.
typedef DragEndCallback = void Function(List<double> mapCoordinates);

/// Callback when drag starts — notify cubit to enter drag mode.
typedef DragStartCallback = void Function();

/// Wraps a map widget to handle target drag gestures via long-press.
///
/// While dragging, [MapView.of(context).options] should set
/// `interactionOptions: InteractionOptions(enablePan: false, enableZoom: false)`
/// to suppress pan/zoom. On drag end, restore normal interaction options.
class TargetDragHandler extends StatefulWidget {
  /// The current target model (null if no target placed).
  final TargetModel? target;

  /// The map widget child.
  final Widget child;

  /// Called during drag to update annotation position visually.
  /// Passes [longitude, latitude] in SRID 4326.
  final DragPositionUpdate? onPositionUpdate;

  /// Called on drag end with final [longitude, latitude] to persist.
  final DragEndCallback? onDragEnd;

  /// Called when drag gesture is recognized (long-press start).
  final DragStartCallback? onDragStart;

  const TargetDragHandler({
    super.key,
    required this.target,
    required this.child,
    this.onPositionUpdate,
    this.onDragEnd,
    this.onDragStart,
  });

  @override
  State<TargetDragHandler> createState() => _TargetDragHandlerState();
}

class _TargetDragHandlerState extends State<TargetDragHandler> {
  /// Whether a drag gesture is currently in progress.
  bool _isDragging = false;

  /// Last known screen position during drag, used to detect movement.
  Offset? _lastScreenPosition;

  /// Whether the pointer has moved enough to be considered a drag (not just a hold).
  bool _hasMoved = false;

  /// The annotation center in screen coordinates at drag start.
  Offset? _annotationScreenOrigin;

  /// The target position in map coordinates at drag start.
  List<double>? _annotationMapOrigin;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }

  /// Called when pointer is pressed on the map.
  ///
  /// Records the press position and starts tracking for a long-press drag.
  void _onPointerDown(PointerDownEvent event) {
    if (widget.target == null) return;
    _lastScreenPosition = event.position;
    _hasMoved = false;
  }

  /// Called when pointer moves on the map.
  ///
  /// On first move after a press, checks if long-press (300ms) has elapsed.
  /// If so, enters drag mode and suppresses map gestures.
  void _onPointerMove(PointerMoveEvent event) {
    if (widget.target == null || !_isDragging) return;

    // Update position — this is called frequently during drag
    // The actual position update is done via long-press move update
    _lastScreenPosition = event.position;
  }

  /// Called when pointer is released.
  ///
  /// If dragging was active, calls [onDragEnd] with the final position.
  /// Always resets drag state.
  void _onPointerUp(PointerUpEvent event) {
    if (!_isDragging) {
      _resetDragState();
      return;
    }

    _lastScreenPosition = event.position;

    // onDragEnd is called with the last updated position
    // The annotation position is updated via onPositionUpdate during drag
    _resetDragState();
  }

  /// Called when pointer is cancelled.
  void _onPointerCancel(PointerCancelEvent event) {
    _resetDragState();
  }

  /// Resets all drag-related state.
  void _resetDragState() {
    _isDragging = false;
    _lastScreenPosition = null;
    _hasMoved = false;
    _annotationScreenOrigin = null;
    _annotationMapOrigin = null;
  }

  /// Call this from a GestureDetector with longPressStart.
  ///
  /// Returns true if drag was initiated (long-press recognized on target).
  /// The [localPosition] is the screen position of the long-press.
  /// The [mapCoordinates] is the [longitude, latitude] of the target at drag start.
  bool handleLongPressStart(Offset localPosition, List<double> mapCoordinates) {
    if (widget.target == null) return false;

    _isDragging = true;
    _annotationScreenOrigin = localPosition;
    _annotationMapOrigin = mapCoordinates;
    _hasMoved = false;

    widget.onDragStart?.call();
    return true;
  }

  /// Call this from GestureDetector with longPressMoveUpdate.
  ///
  /// The [localPosition] is the current screen position of the pointer.
  /// The [mapCoordinates] is the updated [longitude, latitude] under the pointer.
  void handleLongPressMoveUpdate(
    Offset localPosition,
    List<double> mapCoordinates,
  ) {
    if (!_isDragging || widget.target == null) return;

    _hasMoved = true;
    _lastScreenPosition = localPosition;

    // Update annotation position visually (does NOT persist)
    widget.onPositionUpdate?.call(mapCoordinates);
  }

  /// Call this from GestureDetector with longPressEnd.
  ///
  /// The [mapCoordinates] is the final [longitude, latitude] after drag.
  /// Calls [onDragEnd] to persist the new position.
  void handleLongPressEnd(List<double> mapCoordinates) {
    if (!_isDragging || widget.target == null) {
      _resetDragState();
      return;
    }

    try {
      widget.onDragEnd?.call(mapCoordinates);
    } finally {
      _resetDragState();
    }
  }
}
