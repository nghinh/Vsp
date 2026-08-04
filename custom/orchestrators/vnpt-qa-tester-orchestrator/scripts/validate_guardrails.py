#!/usr/bin/env python3
"""Strict config validator for `config/medium-model-guardrails.yaml`.

Scope (P0):
- Validate the v2.0.0 schema: required top-level fields, guardrail booleans,
  response_style, traceability, test_id_prefixes, minimum_per_risk, lists,
  medium_model_decomposition, and the minimax_m2_7_constraints envelope.
- Reject unknown keys under known sub-mappings.
- Reject malformed values (wrong type, empty list, non-bool flag).
- Fail fast on unresolved placeholders or template tokens in config values
  (TODO, TBD, FIXME, XXX, lorem ipsum, {{var}}, ${VAR}, [YOUR_*], etc.).
  Code templates under `automation_code_templates` are explicitly exempt
  because they ARE template content by design.

Usage:
  python scripts/validate_guardrails.py config/medium-model-guardrails.yaml

Exits 0 on PASS, 1 on FAIL, 2 on usage error.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover - explicit user-visible failure
    sys.stderr.write(
        "ERROR: PyYAML is required. Install with: pip install pyyaml\n"
    )
    sys.exit(2)


# =============================================================================
# Schema (v2.0.0 contract)
# =============================================================================

REQUIRED_TOP_LEVEL: tuple[str, ...] = ("orchestrator", "profile", "version")

GUARDRAIL_BOOLS: tuple[str, ...] = (
    "phase_order_is_mandatory",
    "allow_phase_skip",
    "allow_automation_before_oracle",
    "allow_generic_placeholders_as_final",
    "allow_silent_assumptions",
    "allow_shallow_tests_to_count",
)

RESPONSE_STYLE_KEYS: frozenset[str] = frozenset(
    {"required_sections", "forbidden_behaviors"}
)
RESPONSE_STYLE_REQUIRED: tuple[str, ...] = ("required_sections", "forbidden_behaviors")

TRACEABILITY_KEYS: frozenset[str] = frozenset(
    {
        "require_test_id",
        "require_risk_id",
        "require_oracle_id",
        "require_requirement_id_when_available",
        "require_generated_from",
    }
)

TEST_ID_PREFIX_KEYS: frozenset[str] = frozenset(
    {
        "QA-EX-",
        "QA-COMB-",
        "QA-SM-",
        "QA-PROP-",
        "QA-API-",
        "QA-E2E-",
        "QA-REG-",
        "QA-EXP-",
    }
)

MIN_PER_RISK_KEYS: frozenset[str] = frozenset({"P0", "P1"})

MEDIUM_MODEL_DECOMP_KEYS: frozenset[str] = frozenset(
    {"enabled", "table_per_phase", "purpose", "max_gap_unresolved"}
)

MM27_KEYS: frozenset[str] = frozenset(
    {
        "no_visual_evidence",
        "forbidden_evidence_types",
        "required_evidence_types",
        "visual_fallback_label",
        "visual_fallback_required",
        "explicit_commands_required",
        "command_templates",
        "phase_decision_tree",
        "automation_code_templates",
        "gate_report_json_schema",
    }
)

NON_EMPTY_LIST_KEYS: tuple[str, ...] = (
    "required_bug_classes_to_consider",
    "labels_for_uncertainty",
    "patterns_that_do_not_count",
    "what_counts_as_coverage",
    "self_review_checklist",
)

# Paths whose string values are intentionally template content (e.g. Phase 06
# code templates contain <FeatureName>, <expected error message>).
# Exemption is path-prefix based: any descendant of these prefixes is skipped
# by the placeholder scanner.
TEMPLATE_VALUE_PREFIXES: tuple[tuple[str, ...], ...] = (
    ("minimax_m2_7_constraints", "automation_code_templates"),
)

# Strictness knob for the per-key list above. We do not exempt migration
# text, phase decision tree prose, or command templates - those must be
# fully resolved.

SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


# =============================================================================
# Placeholder / unresolved-token detection
# =============================================================================

# Order matters: more specific patterns first so that the reported match
# is the most informative one.
PLACEHOLDER_RULES: tuple[tuple[str, str], ...] = (
    (r"\{\{[^}]+\}\}", "handlebars-style {{var}}"),
    (r"\$\{[A-Z_][A-Z0-9_]*\}", "shell-style ${VAR}"),
    (r"\[YOUR_[A-Z_]+\]", "[YOUR_*] token"),
    (r"\bCHANGEME\b", "CHANGEME token"),
    (r"\bREPLACE_ME\b", "REPLACE_ME token"),
    (r"\bFIXME\b", "FIXME marker"),
    (r"\bXXX\b", "XXX marker"),
    (r"\bTODO\b", "TODO marker"),
    (r"\bTBD\b", "TBD marker"),
    (r"\blorem\s+ipsum\b", "lorem ipsum filler"),
    (r"\bplaceholder\b", "placeholder marker"),
)
_PLACEHOLDER_RES: tuple[tuple[re.Pattern[str], str], ...] = tuple(
    (re.compile(p, re.IGNORECASE), label) for p, label in PLACEHOLDER_RULES
)


def _is_template_path(path: tuple[str, ...]) -> bool:
    """Return True if the value at this path is a documented template body."""
    return any(path[: len(prefix)] == prefix for prefix in TEMPLATE_VALUE_PREFIXES)


def _scan_string_for_placeholders(value: str) -> list[tuple[str, str]]:
    hits: list[tuple[str, str]] = []
    for rx, label in _PLACEHOLDER_RES:
        for m in rx.finditer(value):
            hits.append((m.group(0), label))
    return hits


def _scan_placeholders(
    node: Any, source: Path, path: tuple[str, ...] = ()
) -> list[str]:
    failures: list[str] = []
    if isinstance(node, dict):
        for key, value in node.items():
            failures.extend(_scan_placeholders(value, source, path + (str(key),)))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            failures.extend(_scan_placeholders(value, source, path + (f"[{index}]",)))
    elif isinstance(node, str):
        if _is_template_path(path):
            return failures
        for match, label in _scan_string_for_placeholders(node):
            failures.append(
                f"{source}: unresolved placeholder {match!r} ({label}) at "
                f"{'.'.join(path) or '<root>'}"
            )
    return failures


# =============================================================================
# Schema validation
# =============================================================================

def _is_non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _check_string_list(
    value: Any, key: str, source: Path, failures: list[str]
) -> None:
    if not isinstance(value, list) or not value:
        failures.append(f"{source}: {key} must be a non-empty list")
        return
    for index, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            failures.append(f"{source}: {key}[{index}] must be a non-empty string")


def validate(data: Any, source: Path) -> list[str]:
    failures: list[str] = []

    if not isinstance(data, dict):
        return [f"{source}: top-level must be a mapping, got {type(data).__name__}"]

    # --- Required top-level fields ---
    for key in REQUIRED_TOP_LEVEL:
        if key not in data:
            failures.append(f"{source}: missing required top-level field '{key}'")

    for key in REQUIRED_TOP_LEVEL:
        value = data.get(key)
        if value is not None and not isinstance(value, str):
            failures.append(
                f"{source}: {key} must be a string, got {type(value).__name__}"
            )

    version = data.get("version")
    if isinstance(version, str) and not SEMVER_RE.match(version):
        failures.append(
            f"{source}: version must be semver X.Y.Z, got {version!r}"
        )

    # --- Guardrail booleans ---
    for key in GUARDRAIL_BOOLS:
        value = data.get(key)
        if value is None:
            failures.append(f"{source}: missing guardrail bool '{key}'")
        elif not isinstance(value, bool):
            failures.append(
                f"{source}: {key} must be a bool, got {type(value).__name__}"
            )

    # --- response_style ---
    response_style = data.get("response_style")
    if not isinstance(response_style, dict):
        failures.append(f"{source}: response_style must be a mapping")
    else:
        unknown = set(response_style) - RESPONSE_STYLE_KEYS
        if unknown:
            failures.append(
                f"{source}: response_style has unknown keys: {sorted(unknown)}"
            )
        for key in RESPONSE_STYLE_REQUIRED:
            _check_string_list(
                response_style.get(key), f"response_style.{key}", source, failures
            )

    # --- traceability ---
    traceability = data.get("traceability")
    if not isinstance(traceability, dict):
        failures.append(f"{source}: traceability must be a mapping")
    else:
        unknown = set(traceability) - TRACEABILITY_KEYS
        if unknown:
            failures.append(
                f"{source}: traceability has unknown keys: {sorted(unknown)}"
            )
        for key in TRACEABILITY_KEYS:
            value = traceability.get(key)
            if value is None:
                failures.append(f"{source}: traceability.{key} is required")
            elif not isinstance(value, bool):
                failures.append(
                    f"{source}: traceability.{key} must be a bool, "
                    f"got {type(value).__name__}"
                )

    # --- test_id_prefixes ---
    prefixes = data.get("test_id_prefixes")
    if not isinstance(prefixes, dict):
        failures.append(f"{source}: test_id_prefixes must be a mapping")
    else:
        unknown = set(prefixes) - TEST_ID_PREFIX_KEYS
        if unknown:
            failures.append(
                f"{source}: test_id_prefixes has unknown keys: {sorted(unknown)}"
            )
        missing = TEST_ID_PREFIX_KEYS - set(prefixes)
        if missing:
            failures.append(
                f"{source}: test_id_prefixes missing keys: {sorted(missing)}"
            )
        for key, value in prefixes.items():
            if not isinstance(value, str) or not value.strip():
                failures.append(
                    f"{source}: test_id_prefixes.{key} must be a non-empty string"
                )

    # --- minimum_per_risk ---
    min_per_risk = data.get("minimum_per_risk")
    if not isinstance(min_per_risk, dict):
        failures.append(f"{source}: minimum_per_risk must be a mapping")
    else:
        missing = MIN_PER_RISK_KEYS - set(min_per_risk)
        if missing:
            failures.append(
                f"{source}: minimum_per_risk missing keys: {sorted(missing)}"
            )
        for level in MIN_PER_RISK_KEYS:
            level_value = min_per_risk.get(level)
            if not isinstance(level_value, dict):
                failures.append(
                    f"{source}: minimum_per_risk.{level} must be a mapping"
                )
                continue
            for ck, cv in level_value.items():
                if not _is_non_negative_int(cv):
                    failures.append(
                        f"{source}: minimum_per_risk.{level}.{ck} must be a "
                        f"non-negative int, got {cv!r}"
                    )

    # --- self-review + phase-trace table booleans ---
    for key in (
        "self_review_required_before_final_report",
        "require_phase_trace_table",
    ):
        value = data.get(key)
        if value is not None and not isinstance(value, bool):
            failures.append(
                f"{source}: {key} must be a bool, got {type(value).__name__}"
            )

    phase_trace_format = data.get("phase_trace_table_format")
    if phase_trace_format is not None and not isinstance(phase_trace_format, str):
        failures.append(
            f"{source}: phase_trace_table_format must be a string, "
            f"got {type(phase_trace_format).__name__}"
        )

    # --- medium_model_decomposition ---
    decomp = data.get("medium_model_decomposition")
    if not isinstance(decomp, dict):
        failures.append(f"{source}: medium_model_decomposition must be a mapping")
    else:
        unknown = set(decomp) - MEDIUM_MODEL_DECOMP_KEYS
        if unknown:
            failures.append(
                f"{source}: medium_model_decomposition has unknown keys: "
                f"{sorted(unknown)}"
            )
        for key, expected_type in (
            ("enabled", bool),
            ("table_per_phase", bool),
        ):
            value = decomp.get(key)
            if value is not None and not isinstance(value, expected_type):
                failures.append(
                    f"{source}: medium_model_decomposition.{key} must be a "
                    f"{expected_type.__name__}"
                )
        max_gap = decomp.get("max_gap_unresolved")
        if max_gap is not None and not _is_non_negative_int(max_gap):
            failures.append(
                f"{source}: medium_model_decomposition.max_gap_unresolved must "
                f"be a non-negative int, got {max_gap!r}"
            )
        purpose = decomp.get("purpose")
        if purpose is not None and not isinstance(purpose, str):
            failures.append(
                f"{source}: medium_model_decomposition.purpose must be a string"
            )

    # --- minimax_m2_7_constraints envelope ---
    mm27 = data.get("minimax_m2_7_constraints")
    if mm27 is not None:
        if not isinstance(mm27, dict):
            failures.append(
                f"{source}: minimax_m2_7_constraints must be a mapping"
            )
        else:
            unknown = set(mm27) - MM27_KEYS
            if unknown:
                failures.append(
                    f"{source}: minimax_m2_7_constraints has unknown keys: "
                    f"{sorted(unknown)}"
                )

    # --- Non-empty list keys ---
    for key in NON_EMPTY_LIST_KEYS:
        value = data.get(key)
        if value is not None:
            _check_string_list(value, key, source, failures)

    # --- Placeholder scan (after schema checks so we report structural
    #     problems first). ---
    failures.extend(_scan_placeholders(data, source))

    return failures


# =============================================================================
# CLI
# =============================================================================

def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write(
            "Usage: validate_guardrails.py <config/medium-model-guardrails.yaml>\n"
        )
        return 2

    path = Path(argv[1]).resolve()
    if not path.exists():
        sys.stderr.write(f"ERROR: file not found: {path}\n")
        return 2

    try:
        raw = path.read_text(encoding="utf-8")
        data = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "file": str(path),
                    "failures": [f"{path}: YAML parse error: {exc}"],
                },
                indent=2,
            )
        )
        return 1
    except OSError as exc:
        sys.stderr.write(f"ERROR: cannot read {path}: {exc}\n")
        return 2

    if data is None:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "file": str(path),
                    "failures": [f"{path}: file is empty"],
                },
                indent=2,
            )
        )
        return 1

    failures = validate(data, source=path)
    if failures:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "file": str(path),
                    "version": data.get("version") if isinstance(data, dict) else None,
                    "failures": failures,
                },
                indent=2,
            )
        )
        return 1

    version = data.get("version") if isinstance(data, dict) else None
    print(
        json.dumps(
            {"status": "PASS", "file": str(path), "version": version},
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
