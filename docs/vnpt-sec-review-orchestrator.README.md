# VNPT Security Review Orchestrator

This package adds a security-first review/fix loop for BMAD 6.2.0 + OpenCode.

It does not replace `bmad-vnpt-security`. It only orchestrates it.

It is hardened for mid-tier models such as `minimax/MiniMax-M3` by shipping:
- a strict medium-model contract,
- a recursive BMAD context-reading contract,
- a security context/risk artifact contract,
- JSON schemas for state/findings/backlog/handoff,
- route/scope policy config,
- and a local artifact validator.

## Installed files
- `.opencode/commands/vnpt-sec-review-loop.md`
- `.opencode/agents/vnpt-sec-review-orchestrator.md`
- `.opencode/agents/vnpt-sec-review-auditor.md`
- `.opencode/agents/vnpt-sec-fix-worker.md`
- `docs/vnpt-sec-review-orchestrator.README.md`
- `docs/vnpt-sec-review-orchestrator/STRICT_SECURITY_RULES_FOR_MEDIUM_MODELS.md`
- `docs/vnpt-sec-review-orchestrator/MODEL_BEHAVIOR_CONTRACT.md`
- `docs/vnpt-sec-review-orchestrator/SECURITY_CONTEXT_READING_CONTRACT.md`
- `docs/vnpt-sec-review-orchestrator/SECURITY_ARTIFACT_SCHEMA.md`
- `docs/vnpt-sec-review-orchestrator/schemas/security-review-state.schema.json`
- `docs/vnpt-sec-review-orchestrator/schemas/security-current-pass-findings.schema.json`
- `docs/vnpt-sec-review-orchestrator/schemas/security-live-backlog.schema.json`
- `docs/vnpt-sec-review-orchestrator/schemas/security-handoff.schema.json`
- `docs/vnpt-sec-review-orchestrator/config/medium-model-guardrails.yaml`
- `docs/vnpt-sec-review-orchestrator/config/security-scope-policy.yaml`
- `docs/vnpt-sec-review-orchestrator/config/security-lane-routing.yaml`
- `docs/vnpt-sec-review-orchestrator/tools/validate_security_artifacts.py`

## Usage

```text
/vnpt-sec-review-loop
```

Scope can be a diff, path, subtree, or repository root:

```text
/vnpt-sec-review-loop src/
/vnpt-sec-review-loop .
```

## What it does
1. Discover scope and mode.
2. Recursively inventory BMAD docs under `docs/**` when relevant.
3. Build `security-context-map.md` with 0-EOF proof and `security-risk-map.md` with control-family routing.
4. Infer stack coverage and route the review through `bmad-vnpt-security` lanes.
5. Materialize security review artifacts under `docs/vnpt-flow/<scope-id>/security-review/`.
6. Validate run artifacts with the bundled local validator before completion.
7. Fan out parallel security review subagents by lane or control family.
8. Merge findings, de-duplicate, and build fix waves by write ownership.
9. Run targeted validations and security corroboration.
10. Re-run fresh review passes until the workspace is clean.
11. Run one final confirmation review before stopping.

## Security lanes
The orchestrator routes through the underlying `bmad-vnpt-security` pack, including:
- appsec
- api
- auth
- devsecops
- cloud-k8s
- compliance
- nodejs
- python
- go
- java-spring
- dotnet
- php
- c-cpp
- frontend-react
- frontend-vue
- frontend-angular
- mobile-flutter
- mobile-react
