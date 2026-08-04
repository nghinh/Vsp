#!/usr/bin/env python3
"""Strict validator for vnpt-sec-review-orchestrator run artifacts."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PLACEHOLDERS = ("TODO", "TBD", "lorem ipsum", "placeholder", "fill in")
CLOSED_STATUSES = {"closed", "fixed", "waived", "deferred"}
OPEN_STATUSES = {"open", "in_progress", "stalled"}

REQUIRED_MD = [
    "security-context-map.md",
    "security-risk-map.md",
    "security-fix-plan.md",
    "security-validation-report.md",
    "security-summary.md",
]

REQUIRED_JSON = [
    "security-review-state.json",
    "security-current-pass-findings.json",
    "security-live-backlog.json",
]

SCHEMA_FILES = {
    "security-review-state.json": "schemas/security-review-state.schema.json",
    "security-current-pass-findings.json": "schemas/security-current-pass-findings.schema.json",
    "security-live-backlog.json": "schemas/security-live-backlog.schema.json",
}

SCHEMA_DEFAULTS = {
    "security-review-state.json": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "SecurityReviewState",
        "type": "object",
        "additionalProperties": True,
        "required": [
            "scope_id",
            "scope_source",
            "mode",
            "status",
            "pass_count",
            "open_issue_count_history",
            "latest_pass_id",
            "fresh_confirmation_pass_done",
        ],
        "properties": {
            "scope_id": {"type": "string", "minLength": 1},
            "scope_source": {"type": "string", "minLength": 1},
            "mode": {"type": "string", "minLength": 1},
            "status": {"type": "string", "enum": ["in_progress", "stalled", "complete", "failed"]},
            "pass_count": {"type": "integer", "minimum": 1},
            "open_issue_count_history": {
                "type": "array",
                "minItems": 1,
                "items": {"type": "integer", "minimum": 0},
            },
            "latest_pass_id": {"type": "string", "minLength": 1},
            "fresh_confirmation_pass_done": {"type": "boolean"},
            "latest_zero_issue_pass_id": {"type": ["string", "null"]},
            "closed_issue_ids": {
                "type": "array",
                "items": {"type": "string", "minLength": 1},
            },
            "open_issue_ids": {
                "type": "array",
                "items": {"type": "string", "minLength": 1},
            },
            "scope_resolution": {"type": "string"},
            "scope_policy": {"type": "string"},
        },
    },
    "security-current-pass-findings.json": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "SecurityCurrentPassFindings",
        "type": "array",
        "minItems": 0,
        "items": {
            "type": "object",
            "additionalProperties": True,
            "required": [
                "issue_id",
                "issue_signature",
                "title",
                "severity",
                "category",
                "files",
                "evidence_before",
                "success_condition",
                "status",
            ],
            "properties": {
                "issue_id": {"type": "string", "minLength": 1},
                "issue_signature": {"type": "string", "minLength": 1},
                "title": {"type": "string", "minLength": 1},
                "severity": {"type": "string", "minLength": 1},
                "category": {"type": "string", "minLength": 1},
                "files": {
                    "type": "array",
                    "minItems": 1,
                    "items": {"type": "string", "minLength": 1},
                },
                "evidence_before": {"type": "string", "minLength": 1},
                "evidence_after": {"type": ["string", "null"]},
                "success_condition": {"type": "string", "minLength": 1},
                "status": {
                    "type": "string",
                    "enum": ["open", "fixed", "closed", "waived", "deferred"],
                },
            },
        },
    },
    "security-live-backlog.json": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "SecurityLiveBacklog",
        "type": "array",
        "minItems": 0,
        "items": {
            "type": "object",
            "additionalProperties": True,
            "required": [
                "issue_id",
                "issue_signature",
                "state",
                "owner_scope",
                "priority",
                "title",
                "severity",
                "category",
                "files",
                "evidence_before",
                "success_condition",
            ],
            "properties": {
                "issue_id": {"type": "string", "minLength": 1},
                "issue_signature": {"type": "string", "minLength": 1},
                "state": {"type": "string", "minLength": 1},
                "owner_scope": {"type": "string", "minLength": 1},
                "priority": {"type": "integer", "minimum": 0},
                "title": {"type": "string", "minLength": 1},
                "severity": {"type": "string", "minLength": 1},
                "category": {"type": "string", "minLength": 1},
                "files": {
                    "type": "array",
                    "minItems": 1,
                    "items": {"type": "string", "minLength": 1},
                },
                "evidence_before": {"type": "string", "minLength": 1},
                "evidence_after": {"type": ["string", "null"]},
                "success_condition": {"type": "string", "minLength": 1},
            },
        },
    },
}

CONTRACT_FILES = [
    "config/security-scope-policy.yaml",
    "config/security-lane-routing.yaml",
    "config/medium-model-guardrails.yaml",
]

TRACE_TABLE_HEADER = "| Input checked | Decision made | Output artifact | Open gap | Next action |"
CONTEXT_TABLE_HEADER = "| File | BMAD type | Lines | Discovery path | Read method | 0-EOF status | Scope relevance | Open gaps |"
RISK_TABLE_HEADER = "| Risk ID | Control family | Stack/lane | Evidence | Validation route | Status |"
FIX_TABLE_HEADER = "| Wave | Owned paths | Findings | Worker | Validation | Fallback |"
SUMMARY_TABLE_HEADER = "| Input checked | Decision made | Output artifact | Open gap | Next action |"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def read_json(path: Path):
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def schema_root() -> Path:
    return locate_bundle_root() / "schemas"


def bundle_root() -> Path:
    return locate_bundle_root()


def locate_bundle_root() -> Path:
    script_root = Path(__file__).parent.parent
    cwd = Path.cwd()
    candidates = [
        script_root,
        cwd / "vnpt-bmad-custom" / "vnpt-sec-review-orchestrator",
        cwd / "docs" / "vnpt-sec-review-orchestrator",
        cwd,
    ]
    for candidate in candidates:
        if not candidate.exists():
            continue
        if (candidate / "schemas" / "security-review-state.schema.json").exists() and (
            candidate / "config" / "medium-model-guardrails.yaml"
        ).exists():
            return candidate
    return script_root


def has_placeholder(text: str) -> bool:
    lowered = text.lower()
    return any(marker.lower() in lowered for marker in PLACEHOLDERS)


def validate_schema(instance, schema, path: str = "root") -> list[str]:
    failures: list[str] = []
    if not isinstance(schema, dict):
        return [f"{path}: schema is not an object"]

    schema_type = schema.get("type")
    allowed_types = schema_type if isinstance(schema_type, list) else [schema_type] if schema_type else []

    if allowed_types:
        ok = False
        for t in allowed_types:
            if t == "object" and isinstance(instance, dict):
                ok = True
            elif t == "array" and isinstance(instance, list):
                ok = True
            elif t == "string" and isinstance(instance, str):
                ok = True
            elif t == "integer" and isinstance(instance, int) and not isinstance(instance, bool):
                ok = True
            elif t == "number" and isinstance(instance, (int, float)) and not isinstance(instance, bool):
                ok = True
            elif t == "boolean" and isinstance(instance, bool):
                ok = True
            elif t == "null" and instance is None:
                ok = True
        if not ok:
            return [f"{path}: expected type {schema_type!r}, got {type(instance).__name__}"]

    if "enum" in schema and instance not in schema["enum"]:
        failures.append(f"{path}: value {instance!r} not in enum {schema['enum']!r}")

    if isinstance(instance, str):
        min_length = schema.get("minLength")
        if isinstance(min_length, int) and len(instance) < min_length:
            failures.append(f"{path}: string shorter than minLength {min_length}")
        pattern = schema.get("pattern")
        if isinstance(pattern, str) and not re.search(pattern, instance):
            failures.append(f"{path}: string does not match pattern {pattern!r}")

    if isinstance(instance, int) and not isinstance(instance, bool):
        minimum = schema.get("minimum")
        if isinstance(minimum, int) and instance < minimum:
            failures.append(f"{path}: integer below minimum {minimum}")

    if isinstance(instance, list):
        min_items = schema.get("minItems")
        if isinstance(min_items, int) and len(instance) < min_items:
            failures.append(f"{path}: array shorter than minItems {min_items}")
        items_schema = schema.get("items")
        if isinstance(items_schema, dict):
            for idx, item in enumerate(instance):
                failures.extend(validate_schema(item, items_schema, f"{path}[{idx}]"))

    if isinstance(instance, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in instance:
                failures.append(f"{path}: missing required field {key}")
        properties = schema.get("properties", {})
        if isinstance(properties, dict):
            for key, prop_schema in properties.items():
                if key in instance:
                    failures.extend(validate_schema(instance[key], prop_schema, f"{path}.{key}"))
        if schema.get("additionalProperties") is False:
            allowed = set(properties.keys()) | set(required)
            for key in instance:
                if key not in allowed:
                    failures.append(f"{path}: unexpected property {key}")

    return failures


def validate_schema_file(name: str, payload) -> list[str]:
    schema_path = schema_root() / SCHEMA_FILES[name]
    schema = read_json(schema_path)
    if schema is None:
        schema = SCHEMA_DEFAULTS.get(name)
    if schema is None:
        return [f"Missing bundle schema: {SCHEMA_FILES[name]}"]
    return validate_schema(payload, schema, name)


def validate_contract_files(failures: list[str], warnings: list[str]) -> None:
    root = bundle_root()
    for rel in CONTRACT_FILES:
        path = root / rel
        if not path.exists():
            failures.append(f"Missing bundle contract file: {rel}")
            continue
        text = read_text(path).strip()
        if len(text) < 80:
            failures.append(f"Bundle contract too shallow: {rel}")
        if rel != "config/medium-model-guardrails.yaml" and has_placeholder(text):
            failures.append(f"Placeholder remains in bundle contract: {rel}")

    scope_policy = read_text(root / "config" / "security-scope-policy.yaml")
    if "security-session" not in scope_policy or "security-baseline" not in scope_policy:
        failures.append("security-scope-policy.yaml missing deterministic scope-id fallback rules")
    if "path_prefix" not in scope_policy or "handoff_declared_scope_id" not in scope_policy:
        failures.append("security-scope-policy.yaml missing scope-id derivation rules")

    lane_routing = read_text(root / "config" / "security-lane-routing.yaml")
    for token in ("control_families", "stack_lanes", "fallback_lane", "corroboration_policy"):
        if token not in lane_routing:
            failures.append(f"security-lane-routing.yaml missing {token}")
    if "source_or_config_first" not in lane_routing or "scanners_are_corroboration" not in lane_routing:
        failures.append("security-lane-routing.yaml missing corroboration policy")

    if not (root / "schemas" / "security-review-state.schema.json").exists():
        failures.append("Missing bundle schema directory or security-review-state.schema.json")
    if not (root / "schemas" / "security-current-pass-findings.schema.json").exists():
        failures.append("Missing bundle schema directory or security-current-pass-findings.schema.json")
    if not (root / "schemas" / "security-live-backlog.schema.json").exists():
        failures.append("Missing bundle schema directory or security-live-backlog.schema.json")
    if not (root / "schemas" / "security-handoff.schema.json").exists():
        warnings.append("security-handoff.schema.json is missing; handoff files cannot be machine-checked")


def required_markdown_sections(name: str, text: str, failures: list[str]) -> None:
    lowered = text.lower()
    if len(text.strip()) < 120:
        failures.append(f"Artifact too shallow: {name}")
    if has_placeholder(text):
        failures.append(f"Placeholder remains in artifact: {name}")

    if name == "security-context-map.md":
        for marker in ("BMAD Docs Inventory and 0-EOF Proof", "Stack and Trust Boundary Map", "Source/Config Verification Notes"):
            if marker.lower() not in lowered:
                failures.append(f"{name} missing section: {marker}")
        if CONTEXT_TABLE_HEADER not in text:
            failures.append(f"{name} missing recursive BMAD proof table")
        if "0-EOF" not in text and "READ_0_EOF" not in text:
            failures.append(f"{name} missing 0-EOF proof")
        if "docs/**" not in lowered and "recursive" not in lowered:
            failures.append(f"{name} missing recursive docs/** proof")
    elif name == "security-risk-map.md":
        for marker in ("Control-Family Risk Map", "Stack Detection Result", "Validation Route"):
            if marker.lower() not in lowered:
                failures.append(f"{name} missing section: {marker}")
        if RISK_TABLE_HEADER not in text:
            failures.append(f"{name} missing risk table")
        if "risc-" in lowered:
            pass
        if "risk-" not in lowered and "RISK-" not in text:
            failures.append(f"{name} missing RISK-* identifiers")
        if "control family" not in lowered and "control-family" not in lowered:
            failures.append(f"{name} missing control-family routing")
    elif name == "security-fix-plan.md":
        if "ownership scope" not in lowered:
            failures.append(f"{name} missing ownership scope")
        if "no overlapping write scopes in same wave" not in lowered:
            failures.append(f"{name} missing overlap policy")
        if "sequential fallback for overlapping scopes" not in lowered:
            failures.append(f"{name} missing sequential fallback policy")
        if FIX_TABLE_HEADER not in text:
            failures.append(f"{name} missing wave trace table")
    elif name == "security-validation-report.md":
        for marker in ("Validation Commands", "Validation Result Summary", "Corroboration Evidence"):
            if marker.lower() not in lowered:
                failures.append(f"{name} missing section: {marker}")
        if "validation command" not in lowered and "python" not in lowered:
            failures.append(f"{name} missing validation commands")
    elif name == "security-summary.md":
        for marker in ("Remaining Risks", "Confirmation Review Outcome"):
            if marker.lower() not in lowered:
                failures.append(f"{name} missing section: {marker}")
        if SUMMARY_TABLE_HEADER not in text:
            failures.append(f"{name} missing phase trace table")
        if "remaining risks" not in lowered:
            failures.append(f"{name} missing remaining risks")
        if "confirmation review" not in lowered:
            failures.append(f"{name} missing confirmation review result")


def item_list(payload):
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("findings", "issues", "items", "backlog"):
            value = payload.get(key)
            if isinstance(value, list):
                return value
    return []


def validate_issue_items(name: str, payload, failures: list[str]) -> None:
    schema_failures = validate_schema_file(name, payload)
    failures.extend(schema_failures)
    if schema_failures:
        return

    items = item_list(payload)
    issue_ids: set[str] = set()
    issue_signatures: set[str] = set()
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            failures.append(f"{name}[{idx}] is not an object")
            continue
        issue_id = item.get("issue_id")
        issue_signature = item.get("issue_signature")
        if isinstance(issue_id, str) and issue_id:
            if issue_id in issue_ids:
                failures.append(f"{name} has duplicate issue_id: {issue_id}")
            issue_ids.add(issue_id)
        if isinstance(issue_signature, str) and issue_signature:
            if issue_signature in issue_signatures:
                failures.append(f"{name} has duplicate issue_signature: {issue_signature}")
            issue_signatures.add(issue_signature)
        status = item.get("status") if name == "security-current-pass-findings.json" else item.get("state")
        if status in CLOSED_STATUSES and not str(item.get("evidence_after") or "").strip():
            failures.append(f"{name}[{idx}] closed item missing evidence_after")
        if status in OPEN_STATUSES and name == "security-current-pass-findings.json" and not str(item.get("evidence_before") or "").strip():
            failures.append(f"{name}[{idx}] open finding missing evidence_before")


def validate_state(state, findings, backlog, failures: list[str]) -> None:
    schema_failures = validate_schema_file("security-review-state.json", state)
    failures.extend(schema_failures)
    if schema_failures:
        return

    open_findings = [item for item in findings if isinstance(item, dict) and item.get("status") not in CLOSED_STATUSES]
    open_backlog = [item for item in backlog if isinstance(item, dict) and item.get("state") not in CLOSED_STATUSES]

    pass_count = int(state.get("pass_count", 0) or 0)
    history = state.get("open_issue_count_history", [])
    if not isinstance(history, list) or not history:
        failures.append("security-review-state.json open_issue_count_history must be a non-empty array")
    elif any(not isinstance(v, int) or v < 0 for v in history):
        failures.append("security-review-state.json open_issue_count_history must contain non-negative integers")
    else:
        if pass_count and len(history) > pass_count:
            failures.append("security-review-state.json open_issue_count_history longer than pass_count")

    status = state.get("status")
    if status == "complete":
        if pass_count < 2:
            failures.append("Completed run must include at least two passes")
        if not bool(state.get("fresh_confirmation_pass_done")):
            failures.append("Completed run must record fresh_confirmation_pass_done=true")
        if history and history[-1] != 0:
            failures.append("Completed run must end with zero open issues")
        if open_findings:
            failures.append("Completed run must not keep open current-pass findings")
        if open_backlog:
            failures.append("Completed run must not keep open backlog issues")

    if history and open_backlog and history[-1] == 0 and status != "complete":
        failures.append("Zero open backlog with status not complete")


def validate_optional_handoffs(root: Path, failures: list[str], warnings: list[str]) -> None:
    for handoff_name in ("security-handoff.md", "review-handoff.md"):
        path = root / handoff_name
        if not path.exists():
            continue
        text = read_text(path)
        if len(text.strip()) < 80:
            failures.append(f"Hand-off file too shallow: {handoff_name}")
        if has_placeholder(text):
            failures.append(f"Placeholder remains in hand-off file: {handoff_name}")
        for marker in ("scope_id:", "scope_source:", "mode:"):
            if marker not in text:
                failures.append(f"{handoff_name} missing declared field: {marker}")
        if "touched_scope:" not in text and "changed_files:" not in text:
            warnings.append(f"{handoff_name} does not clearly list touched scope or changed files")


def validate_run(root: Path) -> tuple[dict, list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []

    if not root.exists():
        return (
            {"run_dir": str(root), "status": "FAIL", "failures": [f"Missing run directory: {root}"], "warnings": []},
            [f"Missing run directory: {root}"],
            [],
        )

    validate_contract_files(failures, warnings)
    validate_optional_handoffs(root, failures, warnings)

    md_text = {name: read_text(root / name) for name in REQUIRED_MD}
    json_payload = {name: read_json(root / name) for name in REQUIRED_JSON}

    for name in REQUIRED_MD:
        path = root / name
        text = md_text[name]
        if not path.exists():
            failures.append(f"Missing artifact: {name}")
            continue
        required_markdown_sections(name, text, failures)

    for name in REQUIRED_JSON:
        path = root / name
        payload = json_payload[name]
        if not path.exists():
            failures.append(f"Missing artifact: {name}")
            continue
        if payload is None:
            failures.append(f"{name} is missing or invalid JSON")
            continue
        if name == "security-review-state.json":
            validate_state(payload, item_list(json_payload["security-current-pass-findings.json"]), item_list(json_payload["security-live-backlog.json"]), failures)
        else:
            validate_issue_items(name, payload, failures)

    summary = md_text["security-summary.md"]
    validation = md_text["security-validation-report.md"]
    fix_plan = md_text["security-fix-plan.md"]
    context = md_text["security-context-map.md"]
    risk = md_text["security-risk-map.md"]

    if "BMAD Docs Inventory and 0-EOF Proof" not in context:
        failures.append("security-context-map.md missing BMAD Docs Inventory and 0-EOF Proof")
    if CONTEXT_TABLE_HEADER not in context:
        failures.append("security-context-map.md missing recursive proof table")
    if "0-EOF" not in context and "READ_0_EOF" not in context:
        failures.append("security-context-map.md missing 0-EOF proof")
    if "docs/**" not in context and "recursive" not in context.lower():
        failures.append("security-context-map.md missing recursive docs/** proof")
    if TRACE_TABLE_HEADER not in context:
        failures.append("security-context-map.md missing phase trace table")

    if "RISK-" not in risk:
        failures.append("security-risk-map.md missing RISK-* identifiers")
    if RISK_TABLE_HEADER not in risk:
        failures.append("security-risk-map.md missing risk routing table")
    if TRACE_TABLE_HEADER not in risk:
        failures.append("security-risk-map.md missing phase trace table")

    if "validation commands" not in validation.lower() and "command" not in validation.lower():
        warnings.append("security-validation-report.md does not clearly list validation commands")
    if TRACE_TABLE_HEADER not in summary:
        failures.append("security-summary.md missing trace table")
    if "remaining risks" not in summary.lower():
        failures.append("security-summary.md missing remaining risks")
    if "confirmation review" not in summary.lower():
        failures.append("security-summary.md missing confirmation review result")
    if "no overlapping write scopes" not in fix_plan.lower():
        failures.append("security-fix-plan.md missing overlap policy")
    if "sequential fallback" not in fix_plan.lower():
        failures.append("security-fix-plan.md missing sequential fallback policy")
    if FIX_TABLE_HEADER not in fix_plan:
        failures.append("security-fix-plan.md missing wave trace table")

    result = {
        "run_dir": str(root),
        "status": "FAIL" if failures else "PASS",
        "failures": failures,
        "warnings": warnings,
    }
    return result, failures, warnings


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_security_artifacts.py docs/vnpt-flow/<scope-id>/security-review", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    result, failures, warnings = validate_run(root)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
