---
workflowType: ux-spec
inputDocuments:
  - docs/requirements.md
  - docs/planning-artifacts/prd.md
  - docs/planning-artifacts/architecture.md
sourceSkill: ui-ux-pro-max
documentStatus: draft
project_name: vsp
user_name: nghinh
date: 2026-08-01
---

# UX Specification - Vietnam Smart Golf Platform

## 1. UX Intent

Vietnam Smart Golf Platform must feel reliable outdoors, fast during play, and trustworthy for official course data. The UX is not a generic sports app. It is an on-course decision surface where the golfer has seconds, one hand, sunlight, weak network, GPS noise, and battery constraints.

Primary MVP UX objective:

> Show the right distance, map, score, and course condition with minimum interaction and maximum confidence.

## 2. Product UX Classification

- Product type: hybrid mobile tool + operations dashboard.
- Primary context: outdoor, on-course, one-handed, time-sensitive.
- Secondary context: indoor course operations portal, data editing, verification, audit.
- Style direction: professional, high-contrast, calm, confidence-focused, outdoor-readable.
- Motion direction: subtle only; motion must clarify state, not decorate.
- Density: standard on mobile, denser in portal admin screens.
- Stack assumptions from architecture:
  - Mobile: Flutter.
  - Maps: MapLibre Flutter.
  - Portal: web app, stack TBD.

## 3. Design Principles

1. Glanceable in under 2 seconds.
2. One-hand operation for round-critical flows.
3. Frequent actions complete in two taps or less.
4. Offline status is always understandable.
5. GPS/data confidence is visible but not noisy.
6. Sunlight readability beats visual novelty.
7. No hidden destructive actions.
8. Official vs estimated data must be visually distinct.
9. Accessibility is baseline, not polish.
10. The app must never slow pace of play.

## 4. Design System Direction

Generated from UI/UX Pro Max design-system search for: `golf gps operations portal offline outdoor mobile dashboard`.

### 4.1 Style

Recommended style: **Soft UI Evolution**.

Use subtle depth, clear cards, accessible contrast, and modern enterprise polish. Avoid heavy neumorphism, decorative glass effects, and low-contrast gray-on-gray surfaces.

### 4.2 Color Tokens

Use semantic tokens, not raw hex values in components.

| Token | Value | Usage |
| --- | --- | --- |
| `color.primary` | `#EA580C` | Primary action, selected mode, active target |
| `color.onPrimary` | `#FFFFFF` | Text/icon on primary |
| `color.secondary` | `#F97316` | Secondary emphasis, warning-adjacent highlights |
| `color.accent` | `#059669` | Safe/ready/success states, pace-positive signals |
| `color.background.dark` | `#0F172A` | Outdoor dark base, map overlays, night/dim mode |
| `color.foreground.dark` | `#FFFFFF` | Primary text on dark |
| `color.muted.dark` | `#201C27` | Secondary surfaces |
| `color.border.dark` | `rgba(255,255,255,0.08)` | Dividers and card borders |
| `color.destructive` | `#DC2626` | Danger, delete, severe weather |
| `color.ring` | `#EA580C` | Focus ring and selected control outline |

State colors:

- GPS ready: accent green.
- GPS low accuracy: amber/orange warning.
- Offline ready: green with offline icon label.
- Sync pending: blue/neutral progress.
- Error/destructive: red.
- Official data: green/verified badge.
- Estimated/community data: amber/outlined badge.
- Expired/stale data: red or gray with explicit label.

### 4.3 Typography

Recommended pairing: **Fira Sans + Fira Code**.

- Fira Sans: UI labels, body, navigation, portal tables.
- Fira Code: distance numbers, coordinates, technical metrics where tabular precision helps.
- Base text: 16px equivalent minimum.
- On-course primary distance: very large numeric scale, optimized for sunlight and quick scan.
- Line height: 1.5 for body, tighter only for large numeric distance panels.

### 4.4 Iconography

- Use vector icons only.
- No emoji as structural icons.
- Use one consistent icon family per product surface.
- Icon touch area must be at least 44x44pt on iOS and 48x48dp on Android.
- Icon-only controls require accessible labels.
- Keep stroke width consistent within a hierarchy level.

### 4.5 Spacing and Layout Rhythm

- Use 4/8dp spacing rhythm.
- Mobile page gutters: 16dp minimum, larger on tablet.
- Fixed bottom actions must respect safe area.
- No content hidden behind bottom nav, CTA bars, or system gesture areas.
- Portal uses denser spacing but still keeps 8px rhythm.

## 5. Core Mobile Information Architecture

### 5.1 Bottom Navigation

MVP bottom navigation should contain no more than 5 items:

1. Play
2. Courses
3. Rounds
4. Profile
5. More

During active round, navigation becomes round-focused:

1. Map
2. Score
3. Target
4. Conditions
5. More

### 5.2 Primary Mobile Screens

#### Onboarding/Auth

- Phone/email/social login.
- OTP verification.
- Permission education for location, notifications, and offline storage.
- Do not request all permissions without explaining on-course value.

#### Course Search

- Search bar with nearby course shortcut.
- Favorites and recent courses.
- Course status badges: downloaded, update available, official data, stale data.

#### Course Detail

- Course overview.
- Layouts and holes.
- Download course package CTA.
- Current condition, pin update, green speed, weather snapshot.
- Last verified date and data quality label.

#### Course Download

- Package size.
- Wi-Fi-only option.
- Download progress.
- Last updated/version.
- Offline-ready confirmation.
- Error and retry state.

#### Round Setup

- Course/layout/tee/game format.
- Player selection up to four golfers.
- Mode selection: Casual, Practice, Tournament.
- Active bag selection if available.
- Starting hole selection with auto-suggest.

#### Active Round Map

- Primary screen for MVP.
- Shows current hole, par, golfer position, map, target, pin, wind, GPS state.
- Front/center/back green distances always visible.
- Hazard distances accessible without leaving map.
- Manual hole switch accessible but protected from accidental tap.

#### Scorecard

- Fast gross score entry.
- Putts and penalties optional but accessible.
- Per-player compact cards.
- Save feedback immediate.
- Offline saved indicator visible.

#### Conditions

- Wind, weather, pin, green speed, course condition.
- Source, timestamp, and stale warning.
- Official vs unofficial/estimated labels.

#### Correction Report

- Simple flow: issue type, captured location, optional photo, note, submit.
- Must work offline and sync later.

#### Round Summary

- Scorecard summary.
- Basic stats.
- Sync state.
- Edit later path.

## 6. Active Round UX Requirements

### 6.1 Primary Distance Panel

Must show:

- Front green distance.
- Center green distance.
- Back green distance.
- GPS accuracy state.
- Current hole and par.
- Unit: meters/yards.

Behavior:

- Distance updates within 1 second after location update.
- If GPS is stale or low accuracy, distance panel remains visible but gets confidence warning.
- Do not auto-switch holes under low confidence.

### 6.2 Map Interaction

- Tap map to place target.
- Drag target only if it does not conflict with map pan/zoom.
- Target card shows ball-to-target and target-to-pin distance.
- Map supports high-contrast mode.
- Distance rings must not obscure hazard shapes.

### 6.3 Hazard UX

Hazards should be grouped by relevance:

- Ahead on shot line.
- Near target.
- Current hole overview.

Each hazard row:

- Icon.
- Hazard name/type.
- Near distance.
- Carry/far distance where applicable.
- Confidence/source if not official.

### 6.4 Offline and Sync States

Visible states:

- Online.
- Offline ready.
- Offline but course not downloaded.
- Sync pending.
- Sync failed.
- Package update available.

User-facing copy must be action-oriented:

- “Saved offline. Sync when online.”
- “Course update available.”
- “GPS accuracy low. Manual hole switch recommended.”

## 7. Course Operations Portal UX

### 7.1 Portal Navigation

Primary modules:

1. Dashboard
2. Facilities/Courses
3. Map Editor
4. Pin Positions
5. Green & Course Conditions
6. Alerts
7. Corrections
8. Versions & Audit
9. Users/Roles

### 7.2 Portal Dashboard

Must show:

- Courses needing verification.
- Pending corrections.
- Active alerts.
- Upcoming pin schedules.
- Recent publishes/rollbacks.
- Data freshness and confidence summary.

### 7.3 Map Editor UX

Core requirements:

- Layer list with visibility toggles.
- Draw polygon/line/point tools.
- Edit vertices.
- Snap and undo/redo.
- Import workflow.
- Validation errors before publish.
- Draft/published state clearly visible.

Publishing flow:

1. Validate geometry.
2. Show diff summary.
3. Require publish note.
4. Publish creates version.
5. Trigger package generation.
6. Show package status.

### 7.4 Correction Workflow UX

Correction list fields:

- Type.
- Course/hole.
- Reporter.
- Location.
- Photo/note.
- Status.
- Confidence.
- Submitted time.

Review actions:

- Approve.
- Reject.
- Request more info.
- Convert to draft edit.
- Link to published version.

### 7.5 Admin Audit UX

Audit entries must show:

- Actor.
- Role.
- Action.
- Object changed.
- Before/after summary.
- Timestamp.
- Version.
- Reason/publish note.

## 8. Navigation and Interaction Patterns

### 8.1 Mobile

- Predictable back behavior.
- Deep link to course, round, correction, and package update where possible.
- Bottom nav max 5 items.
- Active round should minimize modal interruptions.
- Destructive actions require confirmation.
- Disabled buttons must explain why when possible.

### 8.2 Portal

- Persistent left navigation for desktop.
- Responsive collapse for tablet.
- Breadcrumbs for course/hole/editor flows.
- Unsaved changes guard in editor.
- Keyboard shortcuts may be added for map editor, but visible buttons remain required.

## 9. Forms and Feedback

- Labels must be visible, not placeholder-only.
- Errors appear near the field.
- Helper text explains format and consequence.
- Numeric inputs use numeric keyboards on mobile.
- Loading state required for async actions.
- Long imports/downloads show progress and can be retried.
- Portal publish actions need success/failure summary.

## 10. Accessibility Requirements

Critical requirements:

- Text contrast at least 4.5:1 for body text.
- Secondary text contrast at least 3:1.
- Touch targets at least 44x44pt iOS / 48x48dp Android.
- Screen reader labels for all meaningful icons and controls.
- Color must not be the only indicator.
- Focus order matches visual order.
- Reduced motion respected.
- Dynamic Type / large text supported.
- Safe areas respected for headers, bottom nav, and CTA bars.

Flutter-specific:

- Use `Semantics` for custom controls.
- Avoid `GestureDetector` without semantics for primary actions.
- Test with VoiceOver and TalkBack.
- Use typed route arguments where feasible.

## 11. Motion Guidelines

Motion tier: subtle.

Allowed:

- Pressed feedback within 80–150ms.
- Screen transitions around 150–300ms.
- Loading spinner/skeleton for async states.
- Small reveal transitions for non-critical portal content.

Avoid:

- Decorative infinite animations.
- Animating width/height where it causes layout thrash.
- Slow animations over 500ms.
- Motion during active round that distracts from play.

## 12. Performance UX Requirements

- Reserve space for map, images, cards, and charts to prevent layout shift.
- Lazy load below-fold images and portal-heavy content.
- Avoid blank screens; use skeletons or meaningful loading states.
- Cache downloaded course states visibly.
- Portal tables should support pagination or virtualization for large correction/audit lists.
- Map layers should be toggleable to reduce clutter and rendering cost.

## 13. Screen-Level MVP Acceptance

### Mobile MVP

- User can find a course and understand whether it is downloadable/offline-ready.
- User can download a course package with clear progress and completion state.
- User can start an 18-hole round.
- User can read front/center/back distance in sunlight-oriented layout.
- User can place a target and understand target distances.
- User can enter score for up to four golfers quickly.
- User can complete round offline without hidden failure.
- User can submit a correction offline.

### Portal MVP

- Admin can edit course data and understand draft vs published state.
- Admin can update pin, green speed, course condition.
- Admin can review correction reports.
- Admin can publish and roll back course data.
- Admin can see audit history.

## 14. UX Risks

| Risk | UX Mitigation |
| --- | --- |
| Outdoor glare makes UI unreadable | Dark/high-contrast outdoor mode, large distance typography |
| Too many on-course options slow play | Active round mode with limited primary actions |
| GPS uncertainty causes bad trust | Visible confidence states and manual override |
| Offline failures hidden until later | Persistent offline/sync state indicators |
| Portal publishes bad geometry | Validation, diff summary, publish notes, rollback |
| Official vs estimated data confusion | Distinct badges and copy for official/estimated/stale |
| Tiny map controls cause errors | 44/48dp touch targets and spacing |
| Visual inconsistency across phases | Semantic tokens and shared design system |

## 15. Pre-Delivery UX Checklist

Before UI implementation is accepted:

- [ ] No emojis used as structural icons.
- [ ] All icons use one consistent vector family/style.
- [ ] Touch targets meet platform minimums.
- [ ] Pressed feedback exists for every tappable control.
- [ ] Primary text contrast meets 4.5:1 in light and dark modes.
- [ ] Secondary text contrast meets 3:1.
- [ ] Color is not the only indicator.
- [ ] Safe areas respected on mobile.
- [ ] Bottom nav has no more than 5 items.
- [ ] Loading states exist for downloads, sync, imports, publish, weather.
- [ ] Reduced motion supported.
- [ ] Dynamic text does not break active round layout.
- [ ] Small phone, large phone, tablet, and landscape verified.
- [ ] Offline states are visible and understandable.
- [ ] Portal editor warns about unsaved changes.
- [ ] Publish/rollback actions are audited and confirmed.

## 16. Open UX Decisions

1. Final mobile icon family.
2. Final portal web stack and component library.
3. Whether MVP supports both light and dark mode at launch or outdoor dark-first only.
4. Exact active-round distance panel layout.
5. Drag target inclusion in MVP after usability test.
6. Map layer color palette after pilot-course satellite/vector validation.
7. Vietnamese-first copywriting tone and terminology.
8. Tablet layout for portal map editor.
