# Source of Truth Map

## Artifact Classification Register

| Path | Classification | Rationale |
|---|---|---|
| `docs/planning-artifacts/prd.md` | current_source | Authoritative product requirements document |
| `docs/planning-artifacts/architecture.md` | current_source | Authoritative architecture decisions |
| `docs/planning-artifacts/ux-spec.md` | current_source | Authoritative UX specifications |
| `docs/planning-artifacts/epics.md` | current_source | Epic and story definitions |
| `docs/implementation-artifacts/epic-01/1-1-*.md` | current_generated | Story 1.1 implementation artifact |
| `docs/implementation-artifacts/epic-01/1-2-*.md` | current_generated | Story 1.2 implementation artifact |
| `docs/implementation-artifacts/epic-01/1-3-*.md` | current_generated | Story 1.3 implementation artifact |
| `docs/implementation-artifacts/epic-01/1-4-*.md` | current_generated | Story 1.4 implementation artifact |
| `docs/implementation-artifacts/epic-01/1-5-*.md` | current_generated | Story 1.5 implementation artifact |
| `docs/bmad-artifacts/stories/*/acceptance-matrix.md` | current_generated | Story completion certificates |
| `docs/bmad-artifacts/epics/epic-01-manifest.md` | current_generated | Epic completion manifest |
| `docs/vnpt-flow/story-*/review-gate.json` | current_generated | Quality gate evidence |
| `docs/vnpt-flow/story-*/re-review-gate.json` | current_generated | Quality gate re-review evidence |
| `packages/design-tokens/` | current_generated | Design token implementations |
| `packages/mobile-theme/` | current_generated | Flutter mobile theme implementation |
| `packages/portal-ui/` | current_generated | Portal CSS implementation |
| `apps/api/src/main/java/vnpt/vsp/module/audit/` | current_generated | Audit infrastructure implementation |
| `apps/api/src/main/java/vnpt/vsp/api/observability/` | current_generated | Observability infrastructure implementation |
| `infra/docker/docker-compose.yaml` | current_generated | Docker infrastructure |
| `infra/scripts/backup.sh` | current_generated | Backup script |
| `docs/ops/backup-retention-policy.md` | current_generated | Backup policy documentation |
| `docs/ops/encryption-policy.md` | current_generated | Encryption policy documentation |
| `.github/workflows/ci-*.yml` | current_generated | CI/CD pipeline configurations |
| `SECRETS_POLICY.md` | current_source | Secrets policy document |

## Classification Key

- **current_source**: Authoritative source documents (PRD, architecture, UX specs)
- **current_generated**: Generated implementation artifacts with quality gate evidence
- **legacy_historical**: Older artifacts from previous versions
- **superseded**: Replaced by more current versions
- **unknown_requires_review**: Needs classification review

## Last Updated
2026-08-02
