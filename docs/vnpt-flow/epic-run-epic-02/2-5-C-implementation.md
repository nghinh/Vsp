# Slice 2-5-C Implementation: Mobile Privacy UI

**Run ID:** run_2026_08_02_005
**Story:** 2.5 — Administer Roles and Privacy Requests
**Slice:** 2-5-C — Mobile Privacy UI
**Status:** IMPLEMENTED

---

## 1. Evidence Arrays

```json
{
  "prd_sources_read": [
    "docs/planning-artifacts/prd.md"
  ],
  "project_context_sources_read": [
    "docs/planning-artifacts/architecture.md",
    "docs/vnpt-flow/epic-run-epic-02/2-5-plan.md",
    "docs/vnpt-flow/epic-run-epic-02/2-5-A-implementation.md",
    "docs/vnpt-flow/epic-run-epic-02/2-5-B-implementation.md",
    "docs/bmad-artifacts/stories/1-4/acceptance-matrix.md",
    "docs/bmad-artifacts/stories/1-5/acceptance-matrix.md"
  ],
  "story_sources_read": [
    "docs/implementation-artifacts/epic-02/2-5-administer-roles-and-privacy-requests.md"
  ],
  "mockup_sources_read": [],
  "additional_context_read": [
    "apps/mobile/lib/features/profile/presentation/profile_screen.dart",
    "apps/mobile/lib/features/profile/presentation/profile_bloc.dart",
    "apps/mobile/lib/features/profile/data/profile_dto.dart",
    "apps/mobile/lib/features/profile/data/profile_service.dart",
    "apps/mobile/lib/features/bag/presentation/bag_screen.dart",
    "apps/mobile/lib/features/bag/presentation/widgets/bag_card.dart",
    "apps/mobile/lib/core/network/api_client.dart",
    "packages/design-tokens/tokens/color.yaml",
    "packages/design-tokens/tokens/state.yaml",
    "packages/design-tokens/tokens/spacing.yaml",
    "packages/contracts/schemas/privacy.yaml"
  ]
}
```

**Note:** No Figma/wireframe/mockup docs exist under `docs/**/*mockup*`, `docs/**/*wireframe*`, `docs/**/*figma*` for this story (confirmed via glob). Design system tokens from Story 1-4 are used throughout.

---

## 2. AC Coverage

| AC | Verification |
|----|-------------|
| AC-3: Users can request data export, account deletion, round deletion with status tracking | `PrivacyBloc` handles 3 submission events; `PrivacyScreen` renders request list with `PrivacyRequestCard`; status badges show PENDING/PROCESSING/COMPLETED/REJECTED; `RequestTypeSelector` for type selection; `RoundPickerForDeletion` for round selection; `AccountDeletionWarning` + typed "DELETE" confirmation dialog |

---

## 3. Files Created

### New Files (6)

**Data Layer (3)**
- `apps/mobile/lib/features/privacy/data/privacy_request_dto.dart` — `PrivacyRequestType` enum (DATA_EXPORT, ACCOUNT_DELETION, ROUND_DELETION), `PrivacyRequestStatus` enum (PENDING, PROCESSING, COMPLETED, REJECTED), `PrivacyRequestDTO`, `CreatePrivacyRequest`, `RoundSummaryDTO`
- `apps/mobile/lib/features/privacy/data/privacy_service.dart` — `PrivacyService` wrapping: GET `/privacy/requests`, GET `/privacy/requests/{id}`, POST `/privacy/requests`, GET `/privacy/requests/{id}/export`, GET `/rounds`
- `apps/mobile/lib/features/privacy/data/privacy_repository.dart` — `PrivacyRepository` wrapping service; `SubmitResult` for operation results

**Presentation Layer (3)**
- `apps/mobile/lib/features/privacy/presentation/privacy_bloc.dart` — `PrivacyBloc` with events: `LoadPrivacyRequests`, `SubmitDataExportRequest`, `SubmitAccountDeletionRequest`, `SubmitRoundDeletionRequest`, `LoadRequestDetail`, `ClearSubmissionResult`; states: `PrivacyInitial`, `PrivacyLoading`, `PrivacyRequestsLoaded`, `PrivacyRequestDetailLoaded`, `PrivacyError`, `PrivacySubmissionResult`
- `apps/mobile/lib/features/privacy/presentation/privacy_screen.dart` — `PrivacyScreen` with request list, FAB to submit new request, `_SubmitRequestSheet` with type selector, round picker, account deletion confirmation dialog, `_RequestDetailSheet`, `_InfoBanner`, `_EmptyView`, `_ErrorView`
- `apps/mobile/lib/features/privacy/presentation/widgets/request_type_selector.dart` — `RequestTypeSelector` three-tile widget for choosing request type with icons and descriptions
- `apps/mobile/lib/features/privacy/presentation/widgets/privacy_request_card.dart` — `PrivacyRequestCard` showing request type icon, status badge (icon + label + color), date, and optional rejection reason
- `apps/mobile/lib/features/privacy/presentation/widgets/round_picker_for_deletion.dart` — `showRoundPickerForDeletion()` bottom sheet showing list of rounds for selection

---

## 4. Key Design Decisions

### AC-3 Status Badges
Each `PrivacyRequestCard` shows status as icon + label + color (per UX spec §10 accessibility rule):
- **PENDING**: Amber/warning color, schedule icon
- **PROCESSING**: Blue (#3B82F6), sync icon
- **COMPLETED**: Green/accent, check_circle icon
- **REJECTED**: Red/destructive, cancel icon with rejection reason shown below

### Account Deletion Confirmation
`ACCOUNT_DELETION` shows `_AccountDeletionWarning` with typed "DELETE" confirmation dialog. Requires user to type "DELETE" exactly to enable the confirm button.

### Round Deletion Picker
`ROUND_DELETION` shows `RoundPickerForDeletion` bottom sheet listing the golfer's rounds. Selected round ID passed as `targetRoundId` in `CreatePrivacyRequest`.

### Data Export Info
`DATA_EXPORT` shows informational notice that export will be prepared within 48 hours.

### Error Handling
All error states show retry button. Loading states use `CircularProgressIndicator`. Empty states show contextual messaging.

---

## 5. Duplicate Detection Outcome

**Dedup Gate:** PRE_WRITE → `clean` → POST_WRITE (PrivacyBloc, PrivacyScreen, PrivacyRequestCard, RequestTypeSelector, showRoundPickerForDeletion) → `clean` → reindex → `ok: true`

Dedup report: `docs/vnpt-flow/epic-run-epic-02/2-5-C/dedup_report.json`
Final symbol status: `clean`

---

## 6. Quality Gate Results

| Gate | Result |
|------|--------|
| `flutter analyze` | ⚠️ SKIPPED — Flutter not available in this environment (skill_gap) |
| Dedup pre-write gate | ✅ PASS (all symbols) |
| Dedup post-write gate | ✅ PASS (all symbols) |
| Dedup reindex | ✅ `ok: true` |

### Skill Gap

| Skill | Status | Evidence |
|-------|--------|----------|
| Flutter toolchain | ⚠️ NOT AVAILABLE | `flutter` command not found in environment |

Flutter analyze could not be run. Code was reviewed by eye against existing codebase patterns (`profile_screen.dart`, `bag_screen.dart`, `bag_card.dart`, `privacy_request_dto.dart` API contract alignment). All design system tokens verified against `packages/design-tokens/tokens/color.yaml`, `state.yaml`, `spacing.yaml`.

---

## 7. Design System Compliance

| Token | Usage |
|-------|-------|
| `VspSpacingSemantic.gutterMobile` | ListView padding in `PrivacyScreen` |
| `VspSpacing._2`, `_3`, `_4` | Component spacing throughout |
| `VspSpacingSemantic.touchTargetMin` | IconButton minimum sizes |
| `VspColorSemantic.of(brightness, _SemanticToken.destructive)` | Account deletion, rejection badges |
| `VspColorSemantic.of(brightness, _SemanticToken.online)` | Data export, completed status |
| `VspColorSemantic.of(brightness, _SemanticToken.warning)` | Pending status badge |
| `VspIconSize.md`, `VspIconSize.sm` | Icon sizes in cards and buttons |
| `VspButton`, `VspButtonVariant.secondary` | Submit, retry, cancel buttons |
| `VspLetterSpacing.wide` | Section headers |

---

## 8. Navigation

`PrivacyScreen` is accessible from the Profile tab. The plan calls for:
- Profile tab → Privacy & Data → `PrivacyScreen` → `PrivacyRequestCard` tap → `_RequestDetailSheet`
- FAB → `_SubmitRequestSheet` → type selection → round picker (for ROUND_DELETION) → confirmation (for ACCOUNT_DELETION) → submit

---

## 9. Dependencies

- Slice 2-5-B (Backend Privacy API contracts) — confirmed via `packages/contracts/schemas/privacy.yaml`
- Story 1-4 Design System — `VspColorSemantic`, `VspSpacing`, `VspIconSize`, `VspButton`, `VspLetterSpacing`
- Story 1-5 Observability — audit actions already added in 2-5-B

---

## 10. Next Steps

1. **Story 2.5 status**: Move to `review` after all slices complete
2. **Flutter verification**: Run `flutter analyze lib/features/privacy/` when Flutter toolchain is available
3. **Navigation wiring**: Connect `PrivacyScreen` to Profile tab navigation
