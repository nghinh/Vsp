// Accessibility Hints — VSP Mobile App
//
// Screen reader and accessibility guidance for the strategic hole map.
// Per UX spec §10 and AC2 (accessibility).

/// Accessibility hints for the strategic hole map feature.
///
/// These hints are used with Semantics widgets and are documented
/// here for QA verification against UX spec §10 requirements.
///
/// ## Screen Reader Labels
///
/// | Element | Semantics Label | Hint |
/// |---------|----------------|------|
/// | Map container | "Strategic hole map for hole N" | — |
/// | Golfer position | "Golfer position: {confidence}, accuracy ±Nm" | — |
/// | Pin marker | "Pin position: {official/estimated}" | — |
/// | Target marker | "Target placed: {label}" | — |
/// | Wind overlay | "Wind: {speed} {unit} from {direction}" | — |
/// | Distance rings | "Distance rings: 100m, 150m, 200m" | — |
/// | Layer toggle | "{N} of {total} layers visible" | — |
/// | Individual layer | "{layer} layer, {visible/hidden}" | "Double tap to toggle" |
/// | Retry button | "Retry loading the hole map" | — |
///
/// ## Touch Interactions
///
/// - **Tap on map**: Places target marker at tap location.
/// - **Long press on map**: Shows context menu (future).
/// - **Pinch**: Zoom map in/out.
/// - **Pan**: Scroll map.
/// - **Layer panel toggle**: Expand/collapse layer visibility list.
/// - **Layer checkbox**: Toggle individual layer visibility.
///
/// ## Accessibility Requirements Met
///
/// - ✅ Text contrast ≥ 4.5:1 (body) / 3:1 (secondary)
/// - ✅ Touch targets ≥ 44×44pt (iOS) / 48×48dp (Android)
/// - ✅ Screen reader labels on all meaningful controls
/// - ✅ Color is not the only indicator (badges + text labels)
/// - ✅ Focus order matches visual order
/// - ✅ Reduced motion respected (no decorative animations)
/// - ✅ Dynamic type / large text supported
/// - ✅ Safe areas respected
///
/// ## Implementation Notes
///
/// - All markers use `Semantics` widget with `label` prop.
/// - Checkboxes use `Semantics` with `button: true`.
/// - `WindArrowOverlay` uses `Transform.rotate` — rotation is decorative,
///   not conveying additional semantic meaning.
/// - `AnimatedContainer` in `LayerTogglePanel` uses 200ms — below
///   the 500ms threshold that requires `reducedMotion` check.
/// - Custom painters (shimmer) should be avoided for reduced-motion
///   users; shimmer animation is disabled when system prefers reduced motion.
class HoleMapAccessibilityHints {
  const HoleMapAccessibilityHints._();
}
