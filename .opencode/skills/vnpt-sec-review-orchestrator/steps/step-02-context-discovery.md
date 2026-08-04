# Step 02: Context Discovery — Recursive BMAD Docs Inventory

**Goal:** Recursively inventory BMAD docs under `docs/**` when relevant; build `security-context-map.md` with 0-EOF proof and source/config evidence summary.

## Sequence

### 1. Recursive BMAD docs discovery

Scan `docs/**` recursively for:
- BMAD process docs: `**/process*.md`, `**/epic*.md`, `**/story*.md`
- Architecture docs: `**/architecture*.md`, `**/likec4/*.md`, `**/likec4/*.likec4`
- PRD docs: `**/prd*.md`, `**/product-requirements*.md`
- Security docs: `**/security*.md`, `**/sec*.md`, `**/auth*.md`
- Config files: `**/config*.yaml`, `**/config*.json`, `**/*.toml`
- Infrastructure: `**/k8s/*.yaml`, `**/dockerfile*`, `**/.github/workflows/**`

### 2. Filter to scope-relevant docs

From the discovered set, retain only docs that intersect with the resolved scope.

### 3. 0-EOF proof per scope-relevant doc

For each retained doc, read 0-EOF (full file) and record:
- File path
- Relevance to scope
- Key security-relevant content (auth, injection, secrets, API surface, dependencies)
- Justified exception if partially read (must document why)

Build a proof table:

| File | Relevance | Security Signals | Read | Gap | Justified Exception |
|------|----------|-----------------|------|-----|---------------------|

### 4. Build security-context-map.md

Write `docs/vnpt-flow/<scope-id>/security-review/security-context-map.md`:

```
# Security Context Map

## Scope
- scope_id: <from state>
- scope_source: <from state>
- mode: <from state>

## BMAD Docs Inventory
[recursive file list grouped by type]

## 0-EOF Proof Table
[the table above]

## Source/Config Evidence Summary
[summarize key auth, injection, secrets, API, dependency surfaces found]

## Phase Trace
| Input checked | Decision made | Output artifact | Open gap | Next action |
|---------------|---------------|-----------------|----------|-------------|
| scope resolved | preflight passed | step 01 done | none | proceed to context map |
```

### 5. Exclusions (HARD)

Exclude from all security work:
- `.opencode/**` (bundled scaffold source)
- `nested vnpt-ai-driven-platform/**` copies
- Unless user explicitly targets these paths

## Outputs

- `docs/vnpt-flow/<scope-id>/security-review/security-context-map.md`

## Next step

After context map is complete, update `security-review-state.json` status to `security_map` and proceed to `step-03-security-map.md`.
