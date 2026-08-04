# Slice Plan — Story 1.4: Establish Design System Foundations

## Evidence of Required Context Reads

| Document | Read | Key Points Applied |
|---|---|---|
| `source-root-contract.json` | ✅ | EffectiveSourceRoot = `/Users/nghinh/Downloads/projects/vsp`; pathRewriteRule=absolute |
| `prd.md` | ✅ | NFR12/NFR13 accessibility + token requirements; UX principles; style direction |
| `architecture.md` | ✅ | Flutter + MapLibre mobile; web portal; modular-monolith backend; design system not yet started |
| `ux-spec.md` | ✅ | All §4 token values; §10 accessibility checklist items; §11 motion guidelines; §15 no-emoji rule |
| `epics.md` | ✅ | Story 1.4 description + Epic 1 delivery sequence; UX-DR10/DR11/DR12 coverage |
| `1-3-establish-api-contracts-and-error-standards.md` | ✅ | Story 1.3 status=done; API contracts package already at `packages/contracts/` |
| Repository structure | ✅ | `apps/mobile/` (Flutter, empty lib); `apps/portal/` (web stub); `packages/contracts/` exists; no design-system package yet |

---

## Story 1.4 Scope Summary

**Story:** As a product team, I want shared semantic design foundations so that mobile and portal remain accessible and consistent.

**Acceptance Criteria (AC):**
1. Semantic color, typography, spacing, icon, focus, elevation, state, and motion tokens are defined.
2. Components support high contrast, large text, reduced motion, loading/error/disabled states, and visible focus.
3. No structural emoji icons or ad-hoc component colors are used.

**Dependency:** Story 1.3 (API contracts + error standards — done ✅)

**Scope surfaces:** Flutter mobile (`apps/mobile/`), Web portal (`apps/portal/`)

---

## Repository Structure Reality

```
apps/
  mobile/          ← Flutter, no lib/ yet, bare pubspec.yaml
  portal/          ← Web stub, package.json scripts are stubs
packages/
  contracts/       ← OpenAPI + schemas (Story 1.3 output ✅)
  course-package/  ← manifest schema
  domain/          ← domain specs stub
  map-style/       ← MapLibre style stub
  [NEW] design-tokens/   ← shared token definitions (platform-agnostic)
  [NEW] mobile-theme/    ← Flutter theme + seed components
  [NEW] portal-ui/      ← portal CSS + seed components
```

---

## Slice Decomposition

### Slice DS-1: Shared Design Tokens Package
**Owner:** `packages/design-tokens/`
**Goal:** Authoritative semantic token definitions in a shared, platform-agnostic form.

| Token Category | Values sourced from | File |
|---|---|---|
| Color | ux-spec §4.2 table + destructive/ring additions | `tokens/color.yaml` |
| Typography | ux-spec §4.3 (Fira Sans + Fira Code) + size/rhythm | `tokens/typography.yaml` |
| Spacing | ux-spec §4.5 (4/8dp rhythm) | `tokens/spacing.yaml` |
| Icon | ux-spec §4.4 (vector, no emoji, 44/48pt touch) | `tokens/icon.yaml` |
| Focus | ux-spec §10 (visible focus ring, 4.5:1 contrast) | `tokens/focus.yaml` |
| Elevation | ux-spec §4.1 Soft UI (shadow/opacity layers) | `tokens/elevation.yaml` |
| State | ux-spec §4.2 + §6.4 (GPS/sync/data-confidence states) | `tokens/state.yaml` |
| Motion | ux-spec §11 (subtle: 80–150ms press, 150–300ms transition) | `tokens/motion.yaml` |

**Constraints enforced by this slice:**
- No raw hex values may be added to component code — only token references
- No emoji as structural icons
- High-contrast dark mode tokens included
- Large-text scaling ratios documented (1.25, 1.5, 2.0 scale factors)

**Verification:** Token files parse correctly; all 8 categories present; no raw hex/color literals outside this package.

---

### Slice DS-2: Flutter Mobile Theme + Seed Components
**Owner:** `apps/mobile/lib/` + `packages/mobile-theme/`
**Goal:** Flutter Material theme fully wired to semantic tokens; loading/error/disabled/accessible seed components.

| Component | Accessibility behaviors |
|---|---|
| `VspButton` | Loading spinner state, disabled opacity, visible focus ring, 44/48pt touch target |
| `VspCard` | Elevation tokens, state color surface support |
| `VspTextField` | Error state, helper/copy, 44pt touch target, reduced motion |
| `VspIcon` | Vector-only enforcement, screen-reader label required |
| `VspLoadingIndicator` | Subtle motion token, reduced-motion suppressed |
| `VspDistanceDisplay` | Large text support, high contrast, reduced motion |

**Flutter-specific implementation:**
- `ThemeData` built entirely from token values (no hardcoded colors in widgets)
- `Semantics` wrapper on every custom control
- `MediaQuery.boldTextOf(context)` respected for large-text mode
- `MediaQuery.disableAnimationsOf(context)` suppresses all non-essential motion
- `FocusNode` + `FocusHighlightMode.automatic` for visible keyboard focus

**Verification:** `flutter analyze` clean; all seed components render in light + dark + high-contrast; reduced-motion respected; screen-reader labels present on icon-only controls.

---

### Slice DS-3: Portal Web CSS Tokens + Seed Components
**Owner:** `apps/portal/` + `packages/portal-ui/`
**Goal:** CSS custom properties from semantic tokens; accessible seed components for portal screens.

| CSS Token Category | Applied via |
|---|---|
| Color | `--vsp-color-*` custom properties on `:root` |
| Typography | `--vsp-font-*` custom properties |
| Spacing | `--vsp-space-*` custom properties (4/8dp multiples) |
| Focus | `:focus-visible` ring using `--vsp-focus-ring` |
| Elevation | `--vsp-shadow-*` box-shadow tokens |
| Motion | CSS `@media (prefers-reduced-motion: reduce)` + `--vsp-duration-*` |

**Seed portal components:**
- `VspButton` (variant: primary/secondary/destructive; states: default/hover/focus/disabled/loading)
- `VspCard` (elevation token, state-aware border)
- `VspFormField` (error, helper, 44pt min touch, label always visible)
- `VspStatusBadge` (official/estimated/stale/pending via state tokens)
- `VspLoadingSkeleton` (subtle shimmer animation, reduced-motion suppressed)

**Verification:** `npm run typecheck` clean; CSS custom properties resolve in both light/dark modes; `:focus-visible` ring visible on keyboard navigation; `prefers-reduced-motion` suppresses shimmer; no emoji icons in component source.

---

## Wave Execution Order

```
Wave 1 ────────────────────────────────────────────────────────
  DS-1  Shared Design Tokens Package
         ↓ tokens/color.yaml, typography.yaml, spacing.yaml,
           icon.yaml, focus.yaml, elevation.yaml, state.yaml, motion.yaml

Wave 2 ────────────────────────────────────────────────────────
  DS-2  Flutter Mobile Theme + Seed Components
         ↓ Flutter ThemeData from tokens
         ↓ VspButton, VspCard, VspTextField, VspIcon,
           VspLoadingIndicator, VspDistanceDisplay
         (can start immediately after DS-1 — no cross-wave dependency)

Wave 3 ────────────────────────────────────────────────────────
  DS-3  Portal Web CSS Tokens + Seed Components
         ↓ CSS custom properties on :root
         ↓ VspButton, VspCard, VspFormField,
           VspStatusBadge, VspLoadingSkeleton
         (can start immediately after DS-1 — no cross-wave dependency)
```

Waves 2 and 3 are fully independent and may run in parallel after Wave 1.

---

## Anti-Shortcut Evidence

| Rule | How enforced in this plan |
|---|---|
| No emoji as icons | `icon.yaml` + `VspIcon` component reject non-vector sources; portal components checked by lint rule |
| No ad-hoc component colors | All color usage in Flutter must reference `Theme.of(context).colorScheme` (from tokens); CSS uses `--vsp-color-*` only |
| High contrast | Dark-mode tokens with ≥4.5:1 ratio defined explicitly; seed components verified in both modes |
| Large text | Typography scale ratios (1.25/1.5/2.0) in `typography.yaml`; `MediaQuery` respected in Flutter |
| Reduced motion | `motion.yaml` defines durations + `reduced-motion: suppress` in both Flutter and CSS |
| Loading/error/disabled states | Each seed component explicitly implements all three states |
| Visible focus | `focus.yaml` ring token; Flutter `FocusHighlightMode.automatic`; CSS `:focus-visible` |

---

## Acceptance Criterion Coverage

| AC | Slices covering it |
|---|---|
| Semantic color tokens defined | DS-1 (tokens/color.yaml) → DS-2 (Flutter ThemeData) → DS-3 (CSS --vsp-color-*) |
| Semantic typography tokens defined | DS-1 (tokens/typography.yaml) → DS-2 → DS-3 |
| Semantic spacing tokens defined | DS-1 (tokens/spacing.yaml) → DS-2 → DS-3 |
| Semantic icon tokens defined | DS-1 (tokens/icon.yaml) → DS-2 → DS-3 |
| Semantic focus tokens defined | DS-1 (tokens/focus.yaml) → DS-2 → DS-3 |
| Semantic elevation tokens defined | DS-1 (tokens/elevation.yaml) → DS-2 → DS-3 |
| Semantic state tokens defined | DS-1 (tokens/state.yaml) → DS-2 → DS-3 |
| Semantic motion tokens defined | DS-1 (tokens/motion.yaml) → DS-2 → DS-3 |
| Components support high contrast | DS-2 (dark mode ThemeData) + DS-3 (CSS dark vars) |
| Components support large text | DS-2 (MediaQuery scaling) + DS-3 (clamp-based fluid scale) |
| Components support reduced motion | DS-2 (MediaQuery.disableAnimationsOf) + DS-3 (prefers-reduced-motion) |
| Components support loading/error/disabled states | DS-2 seed components + DS-3 seed components |
| Components support visible focus | DS-2 (FocusNode) + DS-3 (:focus-visible ring) |
| No structural emoji icons | DS-1 icon.yaml constraint + DS-2 VspIcon enforcement + DS-3 lint rule |
| No ad-hoc component colors | DS-1 token-only constraint + DS-2 ThemeData-only + DS-3 CSS var-only |

---

## Story Status After This Plan

```
story: "1.4"
status: ready-for-dev  ← current
↓
planned-slices: [DS-1, DS-2, DS-3]
wave-order: [DS-1] → [DS-2 ‖ DS-3]
next-state: ready-for-implementer-dispatch
```

**Ready for implementer dispatch.** Wave 1 (DS-1) must complete before Waves 2 and 3 can be verified against token values. DS-2 and DS-3 can be implemented in parallel after DS-1 merges.
