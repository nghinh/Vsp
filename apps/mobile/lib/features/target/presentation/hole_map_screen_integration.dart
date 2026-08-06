// Hole Map Screen — Target Integration Guide
//
// INTEGRATION POINT — Story 6.3 will implement HoleMapScreen.
// This file documents how to connect TargetCubit to HoleMapScreen
// including Slice 2 (drag) and Slice 3 (offline persistence).
//
// ─────────────────────────────────────────────────────────────────────────────
// SLICE 1: TAP-TO-PLACE TARGET (already implemented in Slice 1)
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. Wrap HoleMapScreen with BlocProvider<TargetCubit>:
//    BlocProvider<TargetCubit>(
//      create: (context) => TargetCubit(
//        repository: context.read<TargetRepository>(),
//      )..initialize(roundId: roundId, holeNumber: holeNumber),
//      child: const HoleMapScreen(),
//    )
//
// 2. onMapTap callback → TargetCubit.placeTarget():
//    void _onMapTap(ScreenCoordinate coord) {
//      final mapCoords = await mapController.toLatLng(coord);
//      context.read<TargetCubit>().placeTarget([mapCoords.longitude, mapCoords.latitude]);
//    }
//
// 3. Add TargetAnnotation to map layers using TargetAnnotationConfig
//
// ─────────────────────────────────────────────────────────────────────────────
// SLICE 2: DRAG TARGET WITHOUT PAN/ZOOM CONFLICT
// ─────────────────────────────────────────────────────────────────────────────
//
// Gesture flow:
//   LongPressStart (300ms) → enter drag mode, suppress map gestures
//   LongPressMoveUpdate      → update annotation position visually
//   LongPressEnd             → save new target position, restore map gestures
//
// 1. Wrap map with TargetDragHandler:
//    TargetDragHandler(
//      target: targetState.target,
//      onDragStart: () {
//        cubit.startDrag();
//        // Suppress map pan/zoom:
//        mapController.updateOptions(interactionOptions: InteractionOptions(
//          enablePan: false,
//          enableZoom: false,
//        ));
//      },
//      onPositionUpdate: (mapCoords) {
//        // Update annotation position visually (does NOT persist to DB)
//        annotationUpdater.updatePosition(targetState.target!.id, mapCoords);
//      },
//      onDragEnd: (mapCoords) {
//        cubit.moveTarget(mapCoords);
//        cubit.endDrag();
//        // Restore map pan/zoom:
//        mapController.updateOptions(interactionOptions: InteractionOptions(
//          enablePan: true,
//          enableZoom: true,
//        ));
//      },
//      child: MapLibreMap(...),
//    )
//
// 2. GestureDetector on the target annotation for long-press:
//    GestureDetector(
//      onLongPressStart: (details) {
//        final screenPos = details.localPosition;
//        final mapCoords = await mapController.toScreenCoordinate(targetLatLng);
//        dragHandler.handleLongPressStart(screenPos, mapCoords);
//      },
//      onLongPressMoveUpdate: (details) async {
//        final mapCoords = await _screenToMap(details.globalPosition);
//        dragHandler.handleLongPressMoveUpdate(details.localPosition, mapCoords);
//      },
//      onLongPressEnd: (details) async {
//        final mapCoords = await _screenToMap(details.globalPosition);
//        dragHandler.handleLongPressEnd(mapCoords);
//      },
//      child: TargetAnnotationCircle(...),
//    )
//
// Key UX decisions:
// - Long-press 300ms initiates drag (distinguishes from pan/zoom tap)
// - While dragging: MapLibre interactionOptions disable pan/zoom
// - Drag moves annotation visually; only on LongPressEnd is position persisted
// - Google Maps / Apple Maps marker drag precedent
//
// ─────────────────────────────────────────────────────────────────────────────
// SLICE 3: OFFLINE TARGET PERSISTENCE
// ─────────────────────────────────────────────────────────────────────────────
//
// Target persistence is handled by TargetLocalStore (SQLite, vsp_target.db).
// No server sync required for MVP. Integration points:
//
// 1. Round resume: initialize() loads existing target for round+hole
//    → TargetCubit.initialize(roundId, holeNumber, stubPin) is called on resume
//    → getTarget(roundId, holeNumber) is called internally
//    → TargetState.target is restored with distances
//
// 2. Hole change: setHoleNumber() restores target for new hole
//    → setHoleNumber(holeNumber) is called when golfer changes holes
//    → TargetState.target is updated for the new hole
//
// 3. Offline verification:
//    - Place target → kill app → relaunch → target restored
//    - Works because TargetLocalStore persists to SQLite on disk
//    - No network required for target placement or retrieval
//
// ─────────────────────────────────────────────────────────────────────────────
// STORY 6.5 — Slice 2 & 3: Drag + Offline Persistence
