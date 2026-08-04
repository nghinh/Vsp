# Shared Design Tokens Package
# Vietnam Smart Golf Platform (VSP)

## Overview

This package provides platform-agnostic semantic design tokens for the Vietnam Smart Golf Platform.
Tokens are defined in YAML format and can be consumed by any platform (Flutter, Web, Native, etc.)
without requiring platform-specific transforms.

## Token Categories

| File | Category | Source |
|------|----------|--------|
| `tokens/color.yaml` | Color | UX Spec §4.2 |
| `tokens/typography.yaml` | Typography | UX Spec §4.3 |
| `tokens/spacing.yaml` | Spacing | UX Spec §4.5 |
| `tokens/icon.yaml` | Iconography | UX Spec §4.4 |
| `tokens/focus.yaml` | Focus / Accessibility | UX Spec §4.2, §10 |
| `tokens/elevation.yaml` | Elevation / Shadow | UX Spec §4.1 (Soft UI) |
| `tokens/state.yaml` | State (GPS / Sync / Data) | UX Spec §4.2, §6.4 |
| `tokens/motion.yaml` | Motion / Animation | UX Spec §11 |

## Design Principles

- **Semantic only**: Tokens reference intent (`primary`, `destructive`, `accent`) not raw values.
- **No raw values in components**: All color, spacing, and motion in components must reference tokens.
- **No emoji as icons**: All icons must be vector-based. See `tokens/icon.yaml`.
- **High contrast**: Dark mode tokens meet ≥4.5:1 contrast ratio.
- **Accessible**: Focus rings, touch targets (44pt iOS / 48dp Android), reduced motion.

## Usage

### Reference Syntax

Tokens reference other tokens using the `{category.tokenName}` syntax.
Platform-specific tooling resolves references at build time.

Example:
```yaml
buttonBackground: "{color.primary}"
focusRingColor:   "{focus.ring.color}"
```

### Dark Mode

All color tokens have `light` and `dark` variants.
Semantic aliases (`gpsReady`, `syncPending`, etc.) resolve to the correct variant automatically.

### Token Resolution

Token resolution is performed by consuming packages:

- **Flutter**: `packages/mobile-theme/` consumes tokens → generates `ThemeData` and component tokens.
- **Web/Portal**: `packages/portal-ui/` consumes tokens → generates CSS custom properties.

## Constraints Enforced

| Constraint | Enforcement |
|-----------|------------|
| No raw hex values in component code | Lint rule + token reference-only policy |
| No emoji as structural icons | `tokens/icon.yaml` rule + `VspIcon` component rejects non-vector |
| Touch targets ≥44×44pt iOS / ≥48×48dp Android | `tokens/spacing.yaml` + `tokens/icon.yaml` |
| Reduced motion respected | `tokens/motion.yaml` + platform-specific implementations |
| Visible focus indicators | `tokens/focus.yaml` |
| Color not sole indicator of state | `tokens/state.yaml` requires color + icon + label |

## Accessibility

Per UX Spec §10:

- Body text contrast: ≥4.5:1
- Secondary/caption contrast: ≥3:1
- Focus indicators: ≥4.5:1
- Touch targets: ≥44×44pt (iOS) / ≥48×48dp (Android)
- Screen reader labels on all meaningful icons
- Color not the only state indicator (icon + label required)
- Focus order matches visual order
- Reduced motion supported
- Dynamic Type / large text supported (scale ratios 1.25 / 1.5 / 2.0)

## Motion Guidelines

Per UX Spec §11 (Subtle tier):

- Pressed feedback: 80–150ms
- Screen transitions: 150–300ms
- No decorative infinite animations
- No motion >500ms
- No distracting motion during active round
- Reduced motion: instant transitions (0ms)

## No Emoji Policy

Emoji must **never** be used as structural icons or status indicators.

- GPS status: use vector icon (e.g., location pin, satellite dish)
- Sync status: use vector icon (e.g., cloud with arrow)
- Data confidence: use vector badge icon (e.g., verified checkmark)
- Course status: use vector icon (e.g., download, update)

See `tokens/icon.yaml` for touch target and stroke rules.

## Version

- Package version: 1.0.0
- Aligned with: UX Spec (draft), Epic 1, Story 1.4
