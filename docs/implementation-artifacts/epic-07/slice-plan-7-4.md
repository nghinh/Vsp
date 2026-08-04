# Slice Plan — Story 7.4: Enforce Tournament Mode Restrictions

## Evidence of Context Reading

| Source | Evidence |
|--------|----------|
| `prd.md` §8.12 | Tournament Mode: "MVP includes basic mode flag and configurable feature restrictions. Restricted features must be hidden or disabled. Enabled feature set is auditable. Tournament Mode may lock after round start." |
| `prd.md` §8.4 | Round setup: "mode selection: Casual, Practice, Tournament" |
| `prd.md` §11 (FR19) | "Tournament Mode can restrict disallowed assistance features and lock after round start." |
| `prd.md` §13 Risk | "Tournament rule violations → Tournament Mode, feature restrictions, audit logs" |
| `architecture.md` §14 QG-8 | "Basic Tournament Mode restrictions are represented in config and UI." |
| `architecture.md` §9.2 | Portal RBAC includes "Tournament Director" role |
| `ux-spec.md` §5.2 | Round Setup: "Mode selection: Casual, Practice, Tournament." |
| `epics.md` Story 7.4 AC | "Policy can disable plays-like, elevation, wind adjustment, club recommendation, contours, putting help, and AI." |
| `epics.md` Story 7.4 AC | "Locked mode cannot be changed after round start without authorized workflow." |
| `epics.md` Story 7.4 AC | "Enabled policy and changes are auditable; restricted controls are hidden or disabled with explanation." |
| `slice-plan-5-1.md` | RoundFormat enum already has `tournament` variant; tournament selection UI exists in round setup |
| `epics.md` §7 (Weather) | Features to restrict include wind adjustment (story 7.2) and conditions display (7.3) |
| `epic-07/7-3` story | Pin/conditions display — "source, effective/expiry time, confidence, stale state" — these are candidates for restriction |
| `requirements.md` §691 | "Hide restricted components in Tournament Mode" |
| `requirements.md` §1406 | "Tournament configuration can: disable disallowed features" |

---

## Scope

### What IS in scope (MVP)
- **TournamentPolicy domain model**: flags for each restrictable feature (wind adjustment, plays-like, elevation, club recommendation, contours, putting help, AI)
- **TournamentPolicy.persist()**: store policy against a round or tournament configuration
- **TournamentPolicy audit trail**: every policy creation and change logged with actor, timestamp, before/after
- **Round mode integration**: `RoundFormat.tournament` round stores its `TournamentPolicy`; casual/practice rounds use null policy
- **Lock-after-start enforcement**: once a round starts, `TournamentPolicy` becomes immutable; unlock requires authorized workflow (tournament director role)
- **Feature guard service**: `TournamentFeatureGuard` that answers `isEnabled(roundId, Feature)` — used by UI layers to hide/disable restricted controls
- **UI behavior**: restricted controls hidden or disabled with explanation tooltip ("Restricted in tournament mode")
- **Backend enforcement**: API endpoints for restricted features validate against round policy and return structured error if disabled
- **Epic 7 integration**: wind adjustment (7.2) and conditions display (7.3) respect tournament restrictions

### What is NOT in scope (deferred to Epic 12)
- Tournament creation/management UI (players, flights, tee times, scoring, leaderboards)
- Tournament registration/import
- Official score submission to tournament
- Tournament director authorized unlock workflow (beyond role check)
- Full Strokes Gained, Smart Target AI features (Epic 11)
- Club recommendation (Epic 11)
- Putting help / green contours (future phases)

---

## Slices

### Slice A — TournamentPolicy Domain Model
**Owner: domain / shared contracts**

Tasks:
- [ ] Create `TournamentPolicy` model: `id`, `name`, `windAdjustmentEnabled`, `playsLikeEnabled`, `elevationEnabled`, `clubRecommendationEnabled`, `contoursEnabled`, `puttingHelpEnabled`, `aiFeaturesEnabled`, `isLocked`, `createdAt`, `createdBy`, `version`
- [ ] Create `TournamentFeature` enum: `windAdjustment`, `playsLike`, `elevation`, `clubRecommendation`, `contours`, `puttingHelp`, `aiFeatures`
- [ ] Create `TournamentPolicyChange` audit record: `policyId`, `changedBy`, `changedAt`, `beforeJson`, `afterJson`, `reason`
- [ ] Add `TournamentPolicy.isFeatureEnabled(Feature)` method
- [ ] Add `TournamentPolicy.lock()` method — sets `isLocked = true`; idempotent
- [ ] Add validation: cannot modify any feature flag when `isLocked == true` without `TournamentDirector` role
- [ ] Add `RoundConfig.format == tournament` requires non-null `policyId`
- [ ] Document: null policy = no restrictions (casual/practice); non-null policy = restrictions apply

### Slice B — TournamentPolicy Persistence
**Owner: backend / mobile infrastructure**

Tasks:
- [ ] Create `tournament_policies` table: id (UUID), name, wind_adjustment, plays_like, elevation, club_recommendation, contours, putting_help, ai_features, is_locked, created_at, created_by, version
- [ ] Create `tournament_policy_changes` audit table: id, policy_id, changed_by, changed_at, before_json, after_json, reason
- [ ] Create `TournamentPolicyRepository` with CRUD + lock operations
- [ ] Add `TournamentPolicyRepository.findByRoundId(roundId)` for active round lookup
- [ ] Add idempotency key support on policy create/update
- [ ] Backend: `POST /tournament-policies`, `GET /tournament-policies/{id}`, `PATCH /tournament-policies/{id}` (with lock check), `POST /tournament-policies/{id}/lock`
- [ ] Backend audit: every create/patch/lock emits audit record

### Slice C — Round Integration with Tournament Mode
**Owner: mobile / application + infrastructure**

Tasks:
- [ ] Extend `RoundConfig` model: add `tournamentPolicyId` (nullable); when `format == tournament`, policyId is required
- [ ] Extend `RoundSetupBloc`: when `format == tournament`, fetch or create `TournamentPolicy` for the round; validate policy non-null before allowing start
- [ ] Extend `RoundRepository`: on round create, persist `tournamentPolicyId` in local SQLite; include in sync payload
- [ ] Backend `POST /rounds`: accept optional `tournamentPolicyId`; validate that when format=tournament, policyId is present and policy is not expired
- [ ] Backend: on round start event (status → IN_PROGRESS), auto-call `TournamentPolicy.lock(policyId)` — only if not already locked
- [ ] Backend audit: log round start with tournament mode, policy snapshot

### Slice D — TournamentFeatureGuard Service
**Owner: mobile / application layer**

Tasks:
- [ ] Create `TournamentFeatureGuard` service: `isFeatureEnabled(roundId, Feature): Future<bool>`
- [ ] Implementation: load round → fetch tournamentPolicyId → if null, return true (no restrictions); else fetch policy → call `policy.isFeatureEnabled(feature)`
- [ ] Cache policy per roundId in memory (invalidated on round change or policy update)
- [ ] `TournamentFeatureGuard.getRestrictionReason(roundId, Feature)`: returns localized string explaining why feature is restricted, e.g. "Wind adjustment is disabled in tournament mode"
- [ ] Add offline path: policy cached locally in SQLite; guard works fully offline

### Slice E — Restricted Feature UI Behavior
**Owner: mobile / presentation layer**

Tasks:
- [ ] Identify all UI controls that correspond to restrictable features: wind adjustment toggle (7.2), conditions display (7.3), any plays-like/elevation UI from distance panel, club recommendation, target AI
- [ ] For each restricted control: if `!isFeatureEnabled`, render disabled state + tooltip explaining restriction OR hide the control entirely if hiding is cleaner UX
- [ ] Wind adjustment toggle: when restricted → show disabled toggle with tooltip "Restricted in tournament mode"
- [ ] Club recommendation card: when restricted → hide completely (not applicable in MVP)
- [ ] AI features: when restricted → hide Smart Target button
- [ ] Conditions/putting help: when restricted → hide or show "Not available in tournament" placeholder
- [ ] Add `RestrictionBadge` component: small pill showing "Tournament restricted" with info icon that expands explanation
- [ ] Accessibility: restricted state announced to screen reader; not color-only indicator

### Slice F — Backend API Enforcement
**Owner: backend / api layer**

Tasks:
- [ ] For each restricted feature endpoint, add policy check: fetch round's tournament policy → validate feature flag → return `403 FeatureRestricted` if disabled
- [ ] Wind adjustment endpoint: `GET /weather/adjustment` — add tournament policy check; return `403 {"code":"FEATURE_RESTRICTED","feature":"windAdjustment","message":"..."}`
- [ ] Conditions endpoints: check `puttingHelpEnabled`, `contoursEnabled` flags
- [ ] AI/Smart Target endpoints: check `aiFeaturesEnabled` flag
- [ ] Document: `403 FeatureRestricted` response shape with `feature` and `message` fields
- [ ] Backend: `GET /rounds/{id}/tournament-policy` — return policy for a round (for mobile to consume)

### Slice G — Tournament Policy Admin UI (Portal)
**Owner: portal / presentation**

Tasks:
- [ ] Tournament Director role can view/edit tournament policy
- [ ] Create/Edit policy form: toggle for each feature flag (wind adjustment, plays-like, elevation, club rec, contours, putting help, AI)
- [ ] Lock indicator: visual badge when policy is locked
- [ ] Audit timeline: show policy change history (before/after for each toggle)
- [ ] Policy name and description fields
- [ ] Validation: cannot unlock a locked policy without Tournament Director role confirmation

---

## Verification

### Happy path
- [ ] Casual round → all features enabled, no restriction UI shown
- [ ] Tournament round with default policy → wind adjustment disabled with explanation badge shown
- [ ] Tournament round with custom policy → only enabled features visible
- [ ] Round start → policy auto-locks; subsequent policy edit returns 403 or requires unlock workflow
- [ ] Policy change logged in audit trail with before/after JSON
- [ ] Portal: Tournament Director can create, edit, lock policy

### Negative paths
- [ ] Tournament round with no policyId → round creation fails with validation error
- [ ] Attempt to modify locked policy → API returns 403 with `POLICY_LOCKED` code
- [ ] Restricted feature API called → returns 403 with `FEATURE_RESTRICTED`
- [ ] Non-Tournament Director attempts to unlock → returns 403 Unauthorized
- [ ] Offline: guard uses cached policy correctly; no crash on network failure

### Accessibility
- [ ] Restricted controls have `ExclusionSemantics` or tooltip explaining restriction
- [ ] Screen reader announces restriction reason
- [ ] Touch targets ≥44pt on policy toggle controls
- [ ] Color + icon (not color-only) for restriction indicator

### Performance
- [ ] Feature guard lookup <10ms (in-memory cache)
- [ ] Policy fetch <50ms (local SQLite or API)

---

## File Changes

### New files (backend)
```
apps/api/src/.../tournament/TournamentPolicy.java
apps/api/src/.../tournament/TournamentPolicyRepository.java
apps/api/src/.../tournament/TournamentPolicyController.java
apps/api/src/.../tournament/TournamentPolicyAuditRepository.java
apps/api/src/main/resources/db/migration/VXX__tournament_policies.sql
```

### New files (mobile/domain + contracts)
```
apps/mobile/lib/domain/models/tournament_policy.dart
apps/mobile/lib/domain/models/tournament_feature.dart
apps/mobile/lib/domain/models/tournament_policy_change.dart
packages/contracts/schema/tournament_policy.yaml
```

### New files (mobile/application + infrastructure)
```
apps/mobile/lib/application/services/tournament_feature_guard.dart
apps/mobile/lib/data/repositories/tournament_policy_repository.dart
apps/mobile/lib/data/services/tournament_policy_local_cache.dart
```

### New files (mobile/presentation)
```
apps/mobile/lib/features/round_setup/presentation/tournament_policy_bloc.dart
apps/mobile/lib/features/round_setup/presentation/tournament_policy_event.dart
apps/mobile/lib/features/round_setup/presentation/tournament_policy_state.dart
apps/mobile/lib/features/round_setup/presentation/tournament_policy_screen.dart
apps/mobile/lib/features/round/widgets/restriction_badge.dart
apps/mobile/lib/features/weather/widgets/wind_adjustment_toggle.dart
```

### New files (portal)
```
apps/portal/src/features/tournament-policy/...
```

### Modified files
```
apps/mobile/lib/domain/models/round_config.dart        # add tournamentPolicyId
apps/mobile/lib/features/round_setup/presentation/round_setup_bloc.dart  # tournament mode integration
apps/mobile/lib/data/repositories/round_repository.dart  # persist tournamentPolicyId
apps/api/src/.../round/RoundController.java           # accept tournamentPolicyId in round create
apps/api/src/.../round/RoundService.java              # lock policy on round start
apps/api/src/main/resources/db/migration/VXX__rounds_add_tournament_policy.sql
apps/portal/src/features/round-setup/...              # tournament format → policy editor link
```

---

## Dependencies on Earlier Stories

| Story | Dependency | Gap |
|-------|-----------|-----|
| 5.1 | RoundConfig has `format` (casual/practice/tournament); RoundSetupBloc exists | Need to extend with `tournamentPolicyId` |
| 5.2 | Local SQLite round persistence | Reuse round repository to store `tournamentPolicyId` |
| 5.4 | Round sync idempotency | Tournament policy sync can piggyback round sync |
| 6.4 | Distance calculation engine | Feature flags gate plays-like, elevation UI |
| 7.2 | Wind display relative to shot line | Feature flag `windAdjustmentEnabled` gates wind adjustment toggle |
| 7.3 | Pin/conditions display | Feature flags `puttingHelpEnabled`, `contoursEnabled` gate those sections |
| 1.3 | OpenAPI contracts, error standards | Use `FeatureRestricted` error code from story 1.3 contract standards |
| 1.5 | RBAC roles including Tournament Director | Already defined; used for unlock authorization |
| 8.5 | Pin position management | Tournament Director who sets policy = authorized to update pins |

---

## Quality Gate Alignment

- **FR19**: "Tournament Mode can restrict disallowed assistance features and lock after round start" → TournamentPolicy model + lock mechanism + feature guard ✓
- **PRD §8.12**: Configurable feature restrictions + lock after start + auditable ✓
- **Architecture §14 QG-8**: Basic Tournament Mode restrictions represented in config and UI ✓
- **UX-PR4**: Restricted controls hidden or disabled with explanation ✓
- **UX-A11**: Accessibility — screen reader, non-color-only, ≥44pt targets ✓
- **NFR-Security**: RBAC on policy changes, audit trail ✓
- **NFR-Offline**: Policy cached locally; guard works offline ✓
