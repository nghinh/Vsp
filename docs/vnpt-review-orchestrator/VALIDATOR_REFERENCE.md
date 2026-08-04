# Validator Reference — `validate_review_artifacts.py`

Strict validator for the `vnpt-review-orchestrator` run artifacts. The
validator runs **stdlib only** (no third-party dependency), reads its
policy knobs from `config/medium-model-guardrails.yaml` (`validator_policy:`
block) with safe defaults, and produces an exit code in {0, 1, 2, 3}.

The rule set, the help text, and the YAML policy are kept in lockstep.
If you change a rule, update **all three** of:

1. The validator source (and re-run `py_compile` + the unit tests).
2. `docs/VALIDATOR_REFERENCE.md` (this file).
3. `config/medium-model-guardrails.yaml` → `validator_policy:`.

---

## Exit code matrix

| Code | Meaning |
|------|---------|
| 0    | PASS — every enforced rule satisfied |
| 1    | FAIL — at least one validation failure (or `--strict` promoted warnings) |
| 2    | USAGE — no positional run-dir, run-dir missing, `--config` not found, or malformed REQUIRED JSON (fail-fast) |
| 3    | INTERNAL — uncaught exception in the validator itself |

`--quiet` suppresses the JSON PASS line on stdout but does **not** change
the exit code; exit 0 still means PASS and exit 1 still means FAIL.

---

## CLI flags

| Flag | Effect |
|------|--------|
| `--help`, `-h` | Print the rules summary to stdout and exit 0 |
| `--version` | Print `vnpt-review-orchestrator validate_review_artifacts.py <VERSION>` and exit 0 |
| `--strict` | Promote any `warnings` to `failures`; the validator now exits 1 if any warning was produced |
| `--config <path>` | Load a custom guardrails YAML and use its `validator_policy:` block; falls back to defaults on parse error or missing file |
| `--quiet`, `-q` | Suppress the JSON PASS line on stdout |
| `--diff` | Forward-looking placeholder. The validator prints a notice to stderr and continues with normal validation. No P0 behavior yet. |
| `<run-dir>` (positional) | Path to the orchestrator run directory (the one that contains `review-state.json`, `review-summary.md`, etc.) |

---

## Rule groups (full index)

The validator enforces seven rule groups. The mapping below lists every
check, the function that enforces it in
`tools/validate_review_artifacts.py`, the line range of the check, and
the YAML config knob that tunes it (if any).

### Group 1 — Required artifacts (5 markdown + 3 JSON + 3 contract)

| Check | Source line | Failure message |
|-------|-------------|-----------------|
| `review-context-map.md` exists | `validate_artifacts:734-735` | `Missing artifact: review-context-map.md` |
| `review-risk-map.md` exists | `validate_artifacts:734-735` | `Missing artifact: review-risk-map.md` |
| `review-fix-plan.md` exists | `validate_artifacts:734-735` | `Missing artifact: review-fix-plan.md` |
| `review-validation-report.md` exists | `validate_artifacts:734-735` | `Missing artifact: review-validation-report.md` |
| `review-summary.md` exists | `validate_artifacts:734-735` | `Missing artifact: review-summary.md` |
| `review-state.json` exists | `validate_artifacts:737-738` | `Missing artifact: review-state.json` |
| `review-current-pass-findings.json` exists | `validate_artifacts:737-738` | `Missing artifact: review-current-pass-findings.json` |
| `review-live-backlog.json` exists | `validate_artifacts:737-738` | `Missing artifact: review-live-backlog.json` |
| `config/medium-model-guardrails.yaml` exists | `validate_artifacts:740-742` | `Missing contract file: config/medium-model-guardrails.yaml` |
| `config/review-scope-policy.yaml` exists | `validate_artifacts:740-742` | `Missing contract file: config/review-scope-policy.yaml` |
| `config/review-lane-routing.yaml` exists | `validate_artifacts:740-742` | `Missing contract file: config/review-lane-routing.yaml` |

`review-handoff.json` is **optional**; it is silently treated as absent
when missing or malformed.

### Group 2 — Markdown sections and tables (line-anchored / column-anchored)

`has_section` (`validate_review_artifacts:630-647`) matches a header
line-by-line, **ignoring lines inside fenced code blocks** (```).
`has_table_header` (`validate_review_artifacts:649-661`) compares the
header's stripped cells to a candidate row's stripped cells, so it does
not false-positive on prose that contains the header substring.

| Check | Source line | Failure message |
|-------|-------------|-----------------|
| `review-context-map.md` has `## BMAD Docs Inventory and 0-EOF Proof` | `validate_artifacts:748-757` | `review-context-map.md: missing required section ## BMAD Docs Inventory and 0-EOF Proof` |
| `review-context-map.md` has `## Scope Boundary Notes` | `validate_artifacts:748-757` | `review-context-map.md: missing required section ## Scope Boundary Notes` |
| `review-context-map.md` has `## Source/Config Verification Notes` | `validate_artifacts:748-757` | `review-context-map.md: missing required section ## Source/Config Verification Notes` |
| `review-context-map.md` has `## Phase Trace Table` | `validate_artifacts:748-757` | `review-context-map.md: missing required section ## Phase Trace Table` |
| `review-context-map.md` has the BMAD context table header (8 columns) | `validate_artifacts:748-757` | `review-context-map.md: missing required table header '\| File \| BMAD type \| ... \| Open gaps \|'` |
| `review-context-map.md` has the phase trace table header (5 columns) | `validate_artifacts:748-757` | `review-context-map.md: missing required table header '\| Input checked \| Decision made \| ... \| Next action \|'` |
| `review-risk-map.md` has the four required sections | `validate_artifacts:759-768` | `review-risk-map.md: missing required section <name>` |
| `review-risk-map.md` has the risk table header (6 columns) | `validate_artifacts:759-768` | `review-risk-map.md: missing required table header '\| Risk ID \| ... \| Status \|'` |
| `review-risk-map.md` has the phase trace table header | `validate_artifacts:759-768` | same as above |
| `review-fix-plan.md` has `## Wave Plan` | `validate_artifacts:770-775` | `review-fix-plan.md: missing required section ## Wave Plan` |
| `review-fix-plan.md` has the wave plan table header (6 columns) | `validate_artifacts:770-775` | `review-fix-plan.md: missing required table header '\| Wave \| ... \| Fallback \|'` |
| `review-validation-report.md` has `## Validation Commands` / `## Validation Result Summary` / `## Corroboration Evidence` | `validate_artifacts:777-781` | `review-validation-report.md: missing required section <name>` |
| `review-summary.md` has `## Remaining Risks` / `## Confirmation Review Outcome` / `## Phase Trace Table` | `validate_artifacts:783-788` | `review-summary.md: missing required section <name>` |
| `review-summary.md` has the phase trace table header | `validate_artifacts:783-788` | `review-summary.md: missing required table header '\| Input checked \| ...'` |

### Group 3 — Placeholder / unresolved-token policy

`has_placeholder` (`validate_review_artifacts:662-686`) strips fenced code
blocks (```...```) and inline code spans (`` `...` ``) before scanning,
so a `// TODO` quoted in evidence does not fail.

| Check | Source line | Failure message | YAML knob |
|-------|-------------|-----------------|-----------|
| `TODO` (uppercase, case-sensitive) | `validate_artifacts:678-686`, default patterns at `validate_review_artifacts:121-129` | `<file>.md: contains placeholder marker` | `validator_policy.placeholders` |
| `TBD` (uppercase, case-sensitive) | same | same | same |
| `FIXME` (uppercase, case-sensitive) | same | same | same |
| `XXX` (uppercase, case-sensitive) | same | same | same |
| `lorem ipsum` (case-insensitive) | same | same | same |
| `placeholder` (case-insensitive) | same | same | same |
| `fill in` (case-insensitive) | same | same | same |
| `to be done` (case-insensitive) | same | same | same |
| `to do` (case-insensitive) | same | same | same |

Default placeholder list (in `config/medium-model-guardrails.yaml` →
`validator_policy.placeholders`):
```
\bTODO\b, \bTBD\b, \bFIXME\b, \bXXX\b,
\blorem\s+ipsum\b, \bplaceholder\b, \bfill\s+in\b,
\bto\s+be\s+done\b, \bto\s+do\b
```

### Group 4 — JSON Schema enforcement (enums + required + minLength + minItems)

`validate_schema` (`validate_artifacts:554-628`) is a stdlib JSON Schema
subset validator. It walks the schema and the instance side by side,
enforcing:

- `type` (including nullable / `["string", "null"]` for `evidence_after`)
- `enum` (severity, category, state, status, mode, scope_source)
- `minLength` (required `string` fields)
- `minimum` (integer fields like `priority`, `pass_count`)
- `minItems` (non-empty arrays: `changed_files`, `validated_commands`,
  `known_risks`, `files`, `open_issue_count_history`)
- `required` (every missing field is a failure)
- `additionalProperties` (set to `true` on every schema today, so the
  validator does not error on extra fields)

The on-disk JSON Schemas in `schemas/` and the embedded `SCHEMA_DEFAULTS`
in `tools/validate_review_artifacts.py` are kept in lockstep by the
`test_on_disk_schemas_match_defaults` drift test.

| Check | Source line | YAML knob |
|-------|-------------|-----------|
| `review-state.json` schema (scope_id, scope_source, mode, status, pass_count ≥ 1, open_issue_count_history minItems 1, latest_pass_id, fresh_confirmation_pass_done) | `validate_artifacts:772-786` | `validator_policy.scope_source_enum`, `validator_policy.mode_enum`, `validator_policy.status_enum_run` |
| `review-current-pass-findings.json` schema (issue_id, issue_signature, title, severity, category, files minItems 1, evidence_before, success_condition, status) | `validate_artifacts:772-786` | `validator_policy.severity_enum`, `validator_policy.category_enum`, `validator_policy.state_enum_finding` |
| `review-live-backlog.json` schema (issue_id, issue_signature, state, owner_scope, priority ≥ 0, title, severity, category, files minItems 1, evidence_before, success_condition) | `validate_artifacts:772-786` | `validator_policy.state_enum_backlog`, `validator_policy.severity_enum`, `validator_policy.category_enum` |
| `review-handoff.json` schema (scope_id, scope_source, mode, declared_scope, changed_files minItems 1, validated_commands minItems 1, known_risks minItems 1) | `validate_artifacts:790-804` | `validator_policy.scope_source_enum`, `validator_policy.mode_enum` |
| Malformed REQUIRED JSON → fail-fast as `invalid JSON in <name> (required artifact)` | `validate_artifacts:789-802` | n/a (hard policy) |

### Group 5 — Status / state / evidence invariants

These checks live in `_check_completion_requirements`,
`_check_finding_backlog_consistency`, and `_check_forensics`.

| Check | Source line | Failure message |
|-------|-------------|-----------------|
| `status == "complete"` requires `pass_count >= 2` | `_check_completion_requirements:864-866` | `Completed run must include at least two passes` |
| `status == "complete"` requires `fresh_confirmation_pass_done == true` | `_check_completion_requirements:868-869` | `Completed run must include confirmation pass` |
| `status == "complete"` requires non-empty `open_issue_count_history` | `_check_completion_requirements:871-873` | `Completed run must include a non-empty pass history` |
| `status == "complete"` requires at least one `0` in history | `_check_completion_requirements:874-876` | `Completed run must include a zero-issue pass` |
| `status == "complete"` rejects open current-pass findings | `_check_completion_requirements:878-880` | `Completed run must not keep open current-pass findings` |
| `status == "complete"` rejects open backlog issues | `_check_completion_requirements:882-884` | `Completed run must not keep open backlog issues` |
| Open issue count must decrease over time (no 2-loop non-decreasing run) | `_check_completion_requirements:896-898` | `open issue count is non-decreasing for 2 consecutive loops` |
| Closed finding must have non-null `evidence_after` | `_check_finding_backlog_consistency:978-981` | `<issue_id>: closed item missing evidence_after` |
| Closed backlog item must have non-null `evidence_after` | `_check_finding_backlog_consistency:1019-1023` | `<issue_id>: closed backlog item missing evidence_after` |
| Backlog `state` must be in `validator_policy.state_enum_backlog` | `_check_finding_backlog_consistency:1011-1016` | `<issue_id>: invalid backlog state 'approved'` |
| Finding `status` must be in `validator_policy.state_enum_finding` | enforced by JSON-Schema enum above | `not in enum [...]` |

### Group 6 — Cross-file invariants

| Check | Source line | Failure message |
|-------|-------------|-----------------|
| `len(open_issue_count_history) == pass_count` | `_check_history_invariants:899-908` | `pass history length (N) does not match pass_count (M)` |
| `latest_zero_issue_pass_id` set ⇔ `0 in history` | `_check_history_invariants:910-916` | `latest_zero_issue_pass_id set without 0 in history` / `history contains 0 but latest_zero_issue_pass_id is null` |
| `closed_issue_ids` ∩ `open_issue_ids` == ∅ | `_check_issue_id_sets:919-934` | `issue_id <id> appears in both open_issue_ids and closed_issue_ids` |
| Warning: history tail matches `len(open_issue_ids)` | `_check_issue_id_sets:936-942` | `open/closed counts and history tail do not reconcile (warning): ...` |
| Finding `issue_id` exists in backlog | `_check_finding_backlog_consistency:984-987` | `finding <id> has no matching backlog entry` |
| Backlog `state` and finding `status` are in the same group (open / closed) | `_check_finding_backlog_consistency:991-1003` | `backlog state vs finding status mismatch for <id>: backlog='...' finding='...'` |
| Confirmation pass is the latest pass (id contains `confirm` or ends with `final`/`summary`) | `_check_completion_requirements:886-893` | `confirmation pass must be the latest pass` |
| `forensics.md` ⇔ `status in {stalled, failed}` | `_check_forensics:1086-1100` | `stalled/failed run must include forensics.md (status=...)` / `forensics.md present on non-stalled run (status=...)` |
| No duplicate file paths inside a finding's `files` array | `_check_files_uniqueness:1035-1054` | `<issue_id>: lists the same file path twice` |
| No duplicate file paths inside a backlog item's `files` array | `_check_files_uniqueness:1035-1054` | same |
| Every `validated_commands` entry starts with a runnable prefix | `_check_validated_commands:1058-1084` | `validated_commands contains unrunnable entry '...'` |

YAML knob for the runnable prefix set: `validator_policy.validated_command_prefixes`
(default: see `config/medium-model-guardrails.yaml`).

### Group 7 — CLI / exit code behavior

| Check | Source line | Outcome |
|-------|-------------|---------|
| No positional `run-dir` → exit 2 with `Usage:` on stderr | `main:1165-1170` | exit 2 |
| `--help` / `-h` → print rules summary, exit 0 | `main:1148-1151` | exit 0 |
| `--version` → print `vnpt-review-orchestrator validate_review_artifacts.py <version>`, exit 0 | `main:1153-1156` | exit 0 |
| `--quiet` / `-q` → suppress JSON PASS line; still exit 0/1 | `main:1252-1256` | exit unchanged |
| `--strict` → promote every warning to a failure; exit 1 if any | `main:1234-1237` | exit 0 or 1 |
| `--diff` → emit a forward-looking notice to stderr and continue | `main:1181-1186` | exit unchanged |
| Missing `run-dir` → exit 2 with `not found: <path>` on stderr | `main:1191-1195` | exit 2 |
| `run-dir` is not a directory → exit 2 with `not a directory` on stderr | `main:1196-1198` | exit 2 |
| `--config <path>` not found → exit 2 with `not found` on stderr | `main:1200-1204` | exit 2 |
| Malformed REQUIRED JSON → exit 2 (or fail-fast inside the validator and surface as `invalid JSON in <name>`) | `read_json_strict:493-512`, `main:1217-1224` | exit 2 or 1 |
| Internal exception → exit 3 with `INTERNAL ERROR:` on stderr | `main:1226-1228` | exit 3 |
| Default `--config` lookup → `config/medium-model-guardrails.yaml` in the bundle root | `main:1207-1212` | exit unchanged |

---

## YAML policy knobs (`validator_policy:`)

The validator reads the following keys from the
`validator_policy:` block of `config/medium-model-guardrails.yaml`. If
the file is missing or the block is malformed, the validator falls back
to the built-in defaults defined in
`tools/validate_review_artifacts.py`.

| Key | Type | Default | Effect |
|-----|------|---------|--------|
| `strict_mode_default` | bool | `false` | If true, warnings are promoted to failures even without `--strict` |
| `placeholders` | list[str] | 9 regexes (see Group 3) | Patterns that mark a Markdown body as "contains placeholder" |
| `severity_enum` | list[str] | `["info", "low", "medium", "high", "critical"]` | Allowed `severity` values in findings and backlog |
| `category_enum` | list[str] | 11 values (workflow/review … test/quality) | Allowed `category` values |
| `state_enum_finding` | list[str] | `["open", "fixed", "closed", "waived", "deferred"]` | Allowed `status` values for findings |
| `state_enum_backlog` | list[str] | 7 values (open, in_progress, stalled, fixed, closed, waived, deferred) | Allowed `state` values for backlog items |
| `status_enum_run` | list[str] | `["in_progress", "stalled", "complete", "failed"]` | Allowed `status` values for `review-state.json` |
| `mode_enum` | list[str] | `["diff", "full", "path-arg", "handoff", "manual"]` | Allowed `mode` values in state and handoff |
| `scope_source_enum` | list[str] | `["workspace-diff", "path-arg", "review-handoff", "manual", "agent"]` | Allowed `scope_source` values |
| `validated_command_prefixes` | list[str] | ~30 prefixes (python, pytest, npm test, yarn, playwright, …) | First-whitespace token of each `validated_commands` entry must equal one of these, or the command must start with one followed by whitespace |

The on-disk JSON Schemas in `schemas/*.schema.json` are **not** driven
by the YAML; their enum sets are the authoritative source for the JSON
Schema subset validator. The drift test
`test_on_disk_schemas_match_defaults` ensures the YAML-driven enums and
the schema-driven enums stay in lockstep.

---

## Drift guards (test-only)

- `test_on_disk_schemas_match_defaults` — deep-compares on-disk schema
  enums (`schemas/*.schema.json`) against the embedded `SCHEMA_DEFAULTS`
  enum sets. Run as part of the standard unit-test suite.
- `test_install_smoke_copies_review_bundle_and_verifies_validator` —
  runs the project installer into a scratch directory and asserts
  every file is present, plus `py_compile` succeeds on the installed
  validator.
- `test_help_flag_prints_rules_summary` — asserts the CLI's `--help`
  output mentions every rule group listed above. This guards against
  drift between the implementation and the help text.

---

## Out of scope (P0)

- Source-code parsing or static analysis. The validator only inspects
  the run artifacts, never the reviewed source tree.
- LLM-judge scoring of findings.
- Cross-bundle reconciliation with the `vnpt-dev-story-orchestrator`
  artifacts.
- Forward-looking `--diff` mode (currently a stderr notice only).
