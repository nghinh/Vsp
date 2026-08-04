# Step 06: Validation — Targeted Stack Validation

**Goal:** Run the most relevant targeted validations for the touched stack after fix waves complete.

## Sequence

### 1. Determine validation scope

From the fix wave outputs (files changed, validation commands run), determine:
- Which stacks were touched
- Which validation commands were already run
- Which additional validation commands are relevant but not yet run

### 2. Apply security-aware validation policy

Per stack category:

**Application/API:**
- lint (eslint, ruff, golangci-lint, etc.)
- unit tests
- integration tests
- security checks (bandit, semgrep, gosec, etc.)

**Frontend:**
- lint
- typecheck
- unit tests
- build/smoke test
- browser/security checks (where relevant)

**Backend:**
- lint
- unit/integration tests
- compile/build
- security scanner corroboration

**DevSecOps/Infra:**
- lint/validator (terraform validate, helm lint, etc.)
- syntax/dry-run
- scanner corroboration (trivy, grype, trivy-iac, checkov, etc.)

**Cloud/K8s:**
- kubernetes lint (kube-linter, polaris)
- IaC validation (terraform validate, terraform plan)
- container scanning (trivy, grype)

### 3. Run validation commands

Execute the most relevant targeted validations for the touched paths:
- Prefer targeted commands (only affected paths) over full suite
- Document each command run and its result
- Hard rule: if a required validation command fails, report the failure instead of claiming completion

### 4. Corroboration check

For each fix:
- Scanner output corroborates source/config evidence?
- If scanner finds same issue in fixed code, re-open the finding
- If scanner is clean but source still shows issue, trust source over scanner

### 5. Write security-validation-report.md

```
# Security Validation Report

## Pass ID
<latest_pass_id>

## Validation Commands Run
| Command | Target | Result | Evidence |
|---------|--------|--------|----------|
| npm audit | api-server/ | pass | ... |
| pytest tests/ | auth-backend/ | pass | ... |

## Corroboration Summary
[scanner vs source/config comparison]

## Fix Status
| Issue ID | Fix Validated | Validation | Result |
|----------|--------------|------------|--------|
| SEC-001 | yes | npm audit | pass |

## Phase Trace
| Input checked | Decision made | Output artifact | Open gap | Next action |
|---------------|---------------|-----------------|----------|-------------|
```

## Outputs

- `docs/vnpt-flow/<scope-id>/security-review/security-validation-report.md`

## Next step

After validation, proceed to `step-07-fresh-review.md` for the fresh re-review loop.
