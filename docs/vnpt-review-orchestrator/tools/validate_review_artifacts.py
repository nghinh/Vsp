#!/usr/bin/env python3
"""Strict validator for vnpt-review-orchestrator run artifacts.

Validates the run artifacts an orchestrator produced for a given review:
- Required Markdown and JSON files exist
- Required Markdown sections (line-anchored) and table headers (column-anchored)
- JSON Schema conformance (with embedded defaults as fallback)
- Status / state / evidence_after consistency
- Cross-file invariants between state, findings, backlog, handoff
- Placeholder / unresolved-token detection in Markdown
- Severity, category, mode, state, status enum enforcement
- Confirmation pass must be the latest pass when status == "complete"
- forensics.md iff status in {stalled, failed}
- Duplicate path detection inside each finding/backlog item
- validated_commands starts with a runnable executable prefix

CLI:
  validate_review_artifacts.py <run-dir>
  validate_review_artifacts.py --help | --version
  validate_review_artifacts.py --strict [--config <yaml>] [--quiet] <run-dir>
  validate_review_artifacts.py --diff <run-dir>   # forward-looking placeholder

Exit codes:
  0  PASS
  1  FAIL  (one or more validation failures)
  2  Usage error (no args, missing run dir, malformed REQUIRED JSON)
  3  Internal error

Stdlib only at runtime. No third-party dependency.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Optional

# =============================================================================
# Constants
# =============================================================================

VERSION = "1.0.0"

# Set membership
CLOSED_STATUSES = {"closed", "fixed", "waived", "deferred"}
OPEN_STATUSES = {"open", "in_progress", "stalled"}
ALL_STATUSES = CLOSED_STATUSES | OPEN_STATUSES

# Required / optional artifact lists
REQUIRED_MD = [
    "review-context-map.md",
    "review-risk-map.md",
    "review-fix-plan.md",
    "review-validation-report.md",
    "review-summary.md",
]

REQUIRED_JSON = [
    "review-state.json",
    "review-current-pass-findings.json",
    "review-live-backlog.json",
]

OPTIONAL_JSON = ["review-handoff.json"]
STALLED_JSON = []  # type: list[str]  # reserved for future use

# Schema files and embedded defaults
SCHEMA_FILES = {
    "review-state.json": "schemas/review-state.schema.json",
    "review-current-pass-findings.json": "schemas/review-current-pass-findings.schema.json",
    "review-live-backlog.json": "schemas/review-live-backlog.schema.json",
    "review-handoff.json": "schemas/review-handoff.schema.json",
}

# Enums used by both on-disk JSON Schemas and embedded SCHEMA_DEFAULTS.
# Drift test ensures the two stay in sync.
SEVERITY_ENUM = ["info", "low", "medium", "high", "critical"]
CATEGORY_ENUM = [
    "workflow/review",
    "workflow/fix",
    "code/style",
    "code/logic",
    "code/security",
    "code/performance",
    "config/build",
    "config/ci",
    "docs/missing",
    "test/coverage",
    "test/quality",
]
STATE_ENUM_FINDING = ["open", "fixed", "closed", "waived", "deferred"]
STATE_ENUM_BACKLOG = ["open", "in_progress", "stalled", "fixed", "closed", "waived", "deferred"]
STATUS_ENUM_RUN = ["in_progress", "stalled", "complete", "failed"]
MODE_ENUM = ["diff", "full", "path-arg", "handoff", "manual"]
SCOPE_SOURCE_ENUM = ["workspace-diff", "path-arg", "review-handoff", "manual", "agent"]

# Runnables for validated_commands
VALIDATED_COMMAND_PREFIXES = (
    "python", "pytest", "py.test", "go test", "go vet", "go build",
    "npm test", "npm run", "npx", "yarn", "pnpm",
    "make", "cmake", "bash", "sh", "zsh", "fish",
    "cargo test", "cargo build", "cargo clippy",
    "mvn", "./gradlew", "gradle",
    "phpunit", "phpstan", "vendor/bin/phpunit", "vendor/bin/phpstan",
    "ruby", "rspec", "rake",
    "dotnet", "dotnet test", "dotnet build",
    "swift test", "xcodebuild",
    "jest", "vitest", "mocha",
    "eslint", "flake8", "ruff", "mypy",
    "playwright", "cypress", "schemathesis", "pict", "mutmut", "stryker",
    "node", "tsc", "ts-node",
    "stryker", "mutmut",
)

# Default placeholder tokens.
# Convention: TODO / TBD / FIXME / XXX are uppercase markers by convention;
# matching them case-sensitively avoids false positives on lowercase words
# that happen to contain "tbd" / "todo" / "fixme" / "xxx" as a substring
# (e.g. "tabdil" / "todo list" / "xxx" as a placeholder variable name in
# the middle of a sentence).
# The remaining patterns (lorem ipsum, placeholder, fill in, to be done,
# to do) are case-insensitive because they are natural-language phrases.
DEFAULT_PLACEHOLDERS = (
    r"\bTODO\b",
    r"\bTBD\b",
    r"\bFIXME\b",
    r"\bXXX\b",
    r"\blorem\s+ipsum\b",
    r"\bplaceholder\b",
    r"\bfill\s+in\b",
    r"\bto\s+be\s+done\b",
    r"\bto\s+do\b",
)
# Patterns that must match case-sensitively. Each entry is a regex source
# that is anchored on word boundaries in `has_placeholder`.
PLACEHOLDER_CASE_SENSITIVE = frozenset({
    r"\bTODO\b", r"\bTBD\b", r"\bFIXME\b", r"\bXXX\b",
})

CONTRACT_FILES = [
    "config/medium-model-guardrails.yaml",
    "config/review-scope-policy.yaml",
    "config/review-lane-routing.yaml",
]

TRACE_TABLE_HEADER = "| Input checked | Decision made | Output artifact | Open gap | Next action |"
CONTEXT_TABLE_HEADER = "| File | BMAD type | Lines | Discovery path | Read method | 0-EOF status | Scope relevance | Open gaps |"
RISK_TABLE_HEADER = "| Risk ID | Review concern | Scope lane | Evidence | Validation route | Status |"
FIX_TABLE_HEADER = "| Wave | Owned paths | Findings | Worker | Validation | Fallback |"


# =============================================================================
# Policy
# =============================================================================

@dataclass
class ValidatorPolicy:
    """Tunable knobs the validator reads from the bundle's guardrails YAML.

    Every field has a safe default so the validator runs without a policy
    file. Override by extending the bundle's `medium-model-guardrails.yaml`
    with a `validator_policy:` block.
    """
    strict_mode_default: bool = False
    placeholder_patterns: tuple[str, ...] = DEFAULT_PLACEHOLDERS
    severity_enum: list[str] = field(default_factory=lambda: list(SEVERITY_ENUM))
    category_enum: list[str] = field(default_factory=lambda: list(CATEGORY_ENUM))
    state_enum_finding: list[str] = field(default_factory=lambda: list(STATE_ENUM_FINDING))
    state_enum_backlog: list[str] = field(default_factory=lambda: list(STATE_ENUM_BACKLOG))
    status_enum_run: list[str] = field(default_factory=lambda: list(STATUS_ENUM_RUN))
    mode_enum: list[str] = field(default_factory=lambda: list(MODE_ENUM))
    scope_source_enum: list[str] = field(default_factory=lambda: list(SCOPE_SOURCE_ENUM))
    validated_command_prefixes: tuple[str, ...] = VALIDATED_COMMAND_PREFIXES


# =============================================================================
# Tiny stdlib-only YAML reader (key: value and nested key: [list]).
# Handles the small subset needed by `validator_policy:` in the guardrails
# YAML. NOT a general-purpose YAML parser; if the file uses any feature this
# reader does not understand, the validator falls back to defaults and
# continues.
# =============================================================================

def _strip_inline_comment(s: str) -> str:
    """Remove a trailing '# ...' comment from a line, respecting quotes."""
    in_single = False
    in_double = False
    for index, ch in enumerate(s):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            return s[:index].rstrip()
    return s.rstrip()


def _coerce_scalar(raw: str) -> Any:
    s = raw.strip()
    if not s:
        return ""
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        return s[1:-1]
    if s.lower() in ("true", "yes"):
        return True
    if s.lower() in ("false", "no"):
        return False
    if s.lower() in ("null", "~"):
        return None
    try:
        return int(s)
    except ValueError:
        pass
    try:
        return float(s)
    except ValueError:
        pass
    return s


def _read_minimal_yaml(text: str) -> dict[str, Any]:
    """Parse a tiny subset of YAML:

        key: value
        key:
          - value
          - value
        key: [v1, v2, v3]

    Comments start with '#'. Indentation is space-only and is used to group
    list items under their parent key. Anything more exotic is ignored and
    the loader returns whatever it managed to parse.
    """
    root: dict[str, Any] = {}
    stack: list[tuple[int, Any]] = [(-1, root)]
    for raw_line in text.splitlines():
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        line = _strip_inline_comment(raw_line).rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        content = line.strip()

        # Pop the stack until we find a parent with strictly less indent
        while stack and stack[-1][0] >= indent:
            stack.pop()
        if not stack:
            stack = [(-1, root)]
        parent_indent, parent = stack[-1]

        if content.startswith("- "):
            # list item
            value = _coerce_scalar(content[2:])
            if isinstance(parent, list):
                parent.append(value)
            else:
                # parent should be a list; create one
                # Walk up to replace the most recent dict entry with a list
                # We only support this case if the immediate parent is a list
                # placeholder; otherwise skip silently.
                continue
        elif content.startswith("-") and len(content) > 1 and content[1] in (" ", ""):
            value = _coerce_scalar(content[1:].strip())
            if isinstance(parent, list):
                parent.append(value)
            continue
        elif ":" in content:
            key, _, value_part = content.partition(":")
            key = key.strip()
            value_part = value_part.strip()
            if value_part == "":
                # Start of a block - could be a list or nested mapping
                if isinstance(parent, dict):
                    # Heuristic: look at the next non-empty line to decide
                    # list vs mapping.
                    parent[key] = []
                    stack.append((indent, parent[key]))
            elif value_part.startswith("[") and value_part.endswith("]"):
                # inline list
                inner = value_part[1:-1].strip()
                items = []
                if inner:
                    for raw_item in inner.split(","):
                        items.append(_coerce_scalar(raw_item.strip()))
                if isinstance(parent, dict):
                    parent[key] = items
            else:
                if isinstance(parent, dict):
                    parent[key] = _coerce_scalar(value_part)
    return root


def load_policy(policy_path: Optional[Path]) -> ValidatorPolicy:
    """Build a ValidatorPolicy from a YAML file. Missing file or unreadable
    file → defaults. Unrecognized keys are ignored.
    """
    policy = ValidatorPolicy()
    if policy_path is None or not policy_path.exists():
        return policy
    try:
        text = policy_path.read_text(encoding="utf-8")
    except OSError:
        return policy
    parsed = _read_minimal_yaml(text)
    block = parsed.get("validator_policy")
    if not isinstance(block, dict):
        return policy

    strict = block.get("strict_mode_default")
    if isinstance(strict, bool):
        policy.strict_mode_default = strict

    placeholders = block.get("placeholders")
    if isinstance(placeholders, list) and placeholders:
        compiled: list[str] = []
        for item in placeholders:
            if isinstance(item, str) and item:
                compiled.append(item)
        if compiled:
            policy.placeholder_patterns = tuple(compiled)

    for source_attr, target_attr in (
        ("severity_enum", "severity_enum"),
        ("category_enum", "category_enum"),
        ("state_enum_finding", "state_enum_finding"),
        ("state_enum_backlog", "state_enum_backlog"),
        ("status_enum_run", "status_enum_run"),
        ("mode_enum", "mode_enum"),
        ("scope_source_enum", "scope_source_enum"),
    ):
        v = block.get(source_attr)
        if isinstance(v, list) and v and all(isinstance(x, str) and x for x in v):
            setattr(policy, target_attr, list(v))

    prefixes = block.get("validated_command_prefixes")
    if isinstance(prefixes, list) and prefixes and all(
        isinstance(x, str) and x for x in prefixes
    ):
        policy.validated_command_prefixes = tuple(prefixes)

    return policy


# =============================================================================
# SCHEMA_DEFAULTS — kept in lockstep with on-disk JSON Schemas.
# The DriftTest enforces that the enum sets match.
# =============================================================================

SCHEMA_DEFAULTS: dict[str, Any] = {
    "review-state.json": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "ReviewState",
        "type": "object",
        "additionalProperties": True,
        "required": [
            "scope_id", "scope_source", "mode", "status",
            "pass_count", "open_issue_count_history",
            "latest_pass_id", "fresh_confirmation_pass_done",
        ],
        "properties": {
            "scope_id": {"type": "string", "minLength": 1},
            "scope_source": {"type": "string", "enum": list(SCOPE_SOURCE_ENUM)},
            "mode": {"type": "string", "enum": list(MODE_ENUM)},
            "status": {"type": "string", "enum": list(STATUS_ENUM_RUN)},
            "pass_count": {"type": "integer", "minimum": 1},
            "open_issue_count_history": {
                "type": "array", "minItems": 1,
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
    "review-current-pass-findings.json": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "ReviewCurrentPassFindings",
        "type": "array", "minItems": 0,
        "items": {
            "type": "object", "additionalProperties": True,
            "required": [
                "issue_id", "issue_signature", "title", "severity",
                "category", "files", "evidence_before",
                "success_condition", "status",
            ],
            "properties": {
                "issue_id": {"type": "string", "minLength": 1},
                "issue_signature": {"type": "string", "minLength": 1},
                "title": {"type": "string", "minLength": 1},
                "severity": {"type": "string", "enum": list(SEVERITY_ENUM)},
                "category": {"type": "string", "enum": list(CATEGORY_ENUM)},
                "files": {
                    "type": "array", "minItems": 1,
                    "items": {"type": "string", "minLength": 1},
                },
                "evidence_before": {"type": "string", "minLength": 1},
                "evidence_after": {"type": ["string", "null"]},
                "success_condition": {"type": "string", "minLength": 1},
                "status": {"type": "string", "enum": list(STATE_ENUM_FINDING)},
            },
        },
    },
    "review-live-backlog.json": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "ReviewLiveBacklog",
        "type": "array", "minItems": 0,
        "items": {
            "type": "object", "additionalProperties": True,
            "required": [
                "issue_id", "issue_signature", "state", "owner_scope",
                "priority", "title", "severity", "category",
                "files", "evidence_before", "success_condition",
            ],
            "properties": {
                "issue_id": {"type": "string", "minLength": 1},
                "issue_signature": {"type": "string", "minLength": 1},
                "state": {"type": "string", "enum": list(STATE_ENUM_BACKLOG)},
                "owner_scope": {"type": "string", "minLength": 1},
                "priority": {"type": "integer", "minimum": 0},
                "title": {"type": "string", "minLength": 1},
                "severity": {"type": "string", "enum": list(SEVERITY_ENUM)},
                "category": {"type": "string", "enum": list(CATEGORY_ENUM)},
                "files": {
                    "type": "array", "minItems": 1,
                    "items": {"type": "string", "minLength": 1},
                },
                "evidence_before": {"type": "string", "minLength": 1},
                "evidence_after": {"type": ["string", "null"]},
                "success_condition": {"type": "string", "minLength": 1},
            },
        },
    },
    "review-handoff.json": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "ReviewHandoff",
        "type": "object", "additionalProperties": True,
        "required": [
            "scope_id", "scope_source", "mode", "declared_scope",
            "changed_files", "validated_commands", "known_risks",
        ],
        "properties": {
            "scope_id": {"type": "string", "minLength": 1},
            "scope_source": {"type": "string", "enum": list(SCOPE_SOURCE_ENUM)},
            "mode": {"type": "string", "enum": list(MODE_ENUM)},
            "declared_scope": {"type": "string", "minLength": 1},
            "changed_files": {
                "type": "array", "minItems": 1,
                "items": {"type": "string", "minLength": 1},
            },
            "validated_commands": {
                "type": "array", "minItems": 1,
                "items": {"type": "string", "minLength": 1},
            },
            "known_risks": {
                "type": "array", "minItems": 1,
                "items": {"type": "string", "minLength": 1},
            },
            "residual_gaps": {
                "type": "array",
                "items": {"type": "string", "minLength": 1},
            },
        },
    },
}


# =============================================================================
# File I/O
# =============================================================================

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


class RequiredJsonError(Exception):
    """Raised when a REQUIRED JSON file exists but is malformed."""


def read_json_strict(path: Path, *, required: bool) -> tuple[Optional[Any], bool]:
    """Read JSON from path. Returns (payload, ok).

    - ok=False + payload=None + required=True: malformed REQUIRED file. Caller
      should raise RequiredJsonError to map to exit 2.
    - ok=False + payload=None + required=False: missing or malformed
      OPTIONAL file. Treated as no data, no error.
    - ok=True + payload=None: file did not exist (only when not required).
    - ok=True + payload=<value>: parsed.
    """
    if not path.exists():
        return (None, True) if not required else (None, False)
    try:
        return (json.loads(path.read_text(encoding="utf-8")), True)
    except (json.JSONDecodeError, OSError):
        if required:
            return (None, False)
        return (None, True)


def locate_bundle_root() -> Path:
    script_root = Path(__file__).parent.parent
    cwd = Path.cwd()
    candidates = [
        script_root,
        cwd / "vnpt-bmad-custom" / "vnpt-review-orchestrator",
        cwd / "docs" / "vnpt-review-orchestrator",
        cwd / "custom" / "orchestrators" / "vnpt-review-orchestrator",
        cwd / ".opencode" / "skills" / "vnpt-review-orchestrator",
        cwd,
    ]
    for candidate in candidates:
        if not candidate.exists():
            continue
        if (candidate / "schemas" / "review-state.schema.json").exists() and (
            candidate / "config" / "medium-model-guardrails.yaml"
        ).exists():
            return candidate
    return script_root


def schema_root() -> Path:
    return locate_bundle_root() / "schemas"


def bundle_root() -> Path:
    return locate_bundle_root()


def load_schema(name: str) -> Any:
    schema_path = schema_root() / SCHEMA_FILES[name]
    if schema_path.exists():
        try:
            return json.loads(schema_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return SCHEMA_DEFAULTS[name]
    return SCHEMA_DEFAULTS[name]


# =============================================================================
# JSON Schema validator (stdlib subset)
# =============================================================================

def validate_schema(instance: Any, schema: Any, path: str = "root") -> list[str]:
    failures: list[str] = []
    if not isinstance(schema, dict):
        return [f"{path}: schema is not an object"]

    schema_type = schema.get("type")
    allowed_types = (
        schema_type if isinstance(schema_type, list)
        else [schema_type] if schema_type else []
    )
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
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(instance):
                failures.extend(validate_schema(item, item_schema, f"{path}[{index}]"))

    if isinstance(instance, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in instance:
                failures.append(f"{path}: missing required field {key}")
        props = schema.get("properties", {})
        for key, prop_schema in props.items():
            if key in instance:
                failures.extend(validate_schema(instance[key], prop_schema, f"{path}.{key}"))
        if schema.get("additionalProperties") is False:
            for key in instance:
                if key not in props:
                    failures.append(f"{path}: unexpected field {key}")

    return failures


# =============================================================================
# Markdown checks
# =============================================================================

def has_section(text: str, header: str) -> bool:
    """Line-anchored match: the header must appear at column 0 with optional
    leading whitespace, as a whole line. Lines inside fenced code blocks
    (```...```) are ignored so that a quoted example containing the
    section name does not satisfy the requirement.
    """
    in_fence = False
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if stripped == header:
            return True
    return False


def has_table_header(text: str, header: str) -> bool:
    """Column-anchored match: a line whose stripped cells equal the header's
    cells (after trimming). Avoids false positives on prose that contains
    the header substring.
    """
    expected = [c.strip() for c in header.strip().strip("|").split("|")]
    for line in text.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells == expected:
            return True
    return False


def has_placeholder(text: str, patterns: Iterable[str]) -> bool:
    """Token-aware placeholder detection.

    Matching rules:
    - The patterns in `PLACEHOLDER_CASE_SENSITIVE` (TODO/TBD/FIXME/XXX) are
      case-sensitive: lowercase "tbd" or "todo" inside normal prose does
      not trigger. This is the convention these markers are written in.
    - All other patterns match case-insensitively.
    - Patterns are word-anchored (use \b in the source).
    - Content inside fenced code blocks (```...```) and inline code spans
      (`...`) is stripped before scanning, so that `// TODO` quoted in
      evidence does not fail validation.
    """
    # Strip fenced code blocks and inline code spans before scanning
    no_fence = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    no_fence = re.sub(r"`[^`\n]+`", "", no_fence)
    for pattern in patterns:
        flags = 0 if pattern in PLACEHOLDER_CASE_SENSITIVE else re.IGNORECASE
        if re.search(pattern, no_fence, flags=flags):
            return True
    return False


def check_markdown(
    path: Path,
    required_sections: list[str],
    *,
    required_table_headers: Optional[list[str]] = None,
    placeholder_patterns: Iterable[str] = DEFAULT_PLACEHOLDERS,
) -> list[str]:
    failures: list[str] = []
    text = read_text(path)
    if not text:
        return [f"Missing artifact: {path.name}"]
    for section in required_sections:
        if not has_section(text, section):
            failures.append(f"{path.name}: missing required section {section}")
    for header in required_table_headers or []:
        if not has_table_header(text, header):
            failures.append(f"{path.name}: missing required table header {header!r}")
    if has_placeholder(text, placeholder_patterns):
        failures.append(f"{path.name}: contains placeholder marker")
    return failures


# =============================================================================
# Validation
# =============================================================================

@dataclass
class ValidationResult:
    failures: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.failures and not self.warnings


def validate_artifacts(
    run_dir: Path,
    *,
    policy: Optional[ValidatorPolicy] = None,
) -> ValidationResult:
    """Validate the run artifacts under `run_dir`. Returns a ValidationResult
    with separate failure and warning lists. Use --strict to promote
    warnings to failures at the CLI layer.
    """
    pol = policy or ValidatorPolicy()
    result = ValidationResult()

    # --- Required file presence ---
    for md_name in REQUIRED_MD:
        if not (run_dir / md_name).exists():
            result.failures.append(f"Missing artifact: {md_name}")
    for json_name in REQUIRED_JSON:
        if not (run_dir / json_name).exists():
            result.failures.append(f"Missing artifact: {json_name}")
    for rel in CONTRACT_FILES:
        if not (bundle_root() / rel).exists():
            result.failures.append(f"Missing contract file: {rel}")
    if result.failures:
        return result

    # --- Markdown sections + tables + placeholders ---
    result.failures.extend(check_markdown(
        run_dir / "review-context-map.md",
        [
            "## BMAD Docs Inventory and 0-EOF Proof",
            "## Scope Boundary Notes",
            "## Source/Config Verification Notes",
            "## Phase Trace Table",
        ],
        required_table_headers=[CONTEXT_TABLE_HEADER, TRACE_TABLE_HEADER],
        placeholder_patterns=pol.placeholder_patterns,
    ))
    result.failures.extend(check_markdown(
        run_dir / "review-risk-map.md",
        [
            "## Review Risk Taxonomy",
            "## Stack / Scope Routing",
            "## Validation Route",
            "## Phase Trace Table",
        ],
        required_table_headers=[RISK_TABLE_HEADER, TRACE_TABLE_HEADER],
        placeholder_patterns=pol.placeholder_patterns,
    ))
    result.failures.extend(check_markdown(
        run_dir / "review-fix-plan.md",
        ["## Wave Plan"],
        required_table_headers=[FIX_TABLE_HEADER],
        placeholder_patterns=pol.placeholder_patterns,
    ))
    result.failures.extend(check_markdown(
        run_dir / "review-validation-report.md",
        ["## Validation Commands", "## Validation Result Summary", "## Corroboration Evidence"],
        placeholder_patterns=pol.placeholder_patterns,
    ))
    result.failures.extend(check_markdown(
        run_dir / "review-summary.md",
        ["## Remaining Risks", "## Confirmation Review Outcome", "## Phase Trace Table"],
        required_table_headers=[TRACE_TABLE_HEADER],
        placeholder_patterns=pol.placeholder_patterns,
    ))

    # --- JSON load + schema ---
    state: Any = {}
    findings: list[Any] = []
    backlog: list[Any] = []
    handoff: Any = None

    for json_name in REQUIRED_JSON:
        payload, ok = read_json_strict(run_dir / json_name, required=True)
        if not ok:
            # Malformed REQUIRED JSON
            result.failures.append(
                f"invalid JSON in {json_name} (required artifact)"
            )
            continue
        if payload is None:
            result.failures.append(f"{json_name}: missing or empty")
            continue
        schema = load_schema(json_name)
        result.failures.extend(validate_schema(payload, schema, json_name))
        if json_name == "review-state.json":
            state = payload
        elif json_name == "review-current-pass-findings.json":
            findings = payload
        elif json_name == "review-live-backlog.json":
            backlog = payload

    for json_name in OPTIONAL_JSON:
        payload, ok = read_json_strict(run_dir / json_name, required=False)
        if not ok:
            continue  # missing is fine for optional
        if payload is None:
            continue
        schema = load_schema(json_name)
        result.failures.extend(validate_schema(payload, schema, json_name))
        if json_name == "review-handoff.json":
            handoff = payload

    # If any REQUIRED JSON was malformed, skip cross-file checks (we have no
    # clean inputs to reason over). Cross-file checks would only add noise.
    if any(f.startswith("invalid JSON in ") for f in result.failures):
        return result

    # --- Cross-file invariants ---
    _check_completion_requirements(
        state, findings, backlog, result, policy=pol
    )
    _check_history_invariants(state, result, policy=pol)
    _check_issue_id_sets(state, result, policy=pol)
    _check_finding_backlog_consistency(findings, backlog, result, policy=pol)
    _check_files_uniqueness(findings, "review-current-pass-findings.json", result)
    _check_files_uniqueness(backlog, "review-live-backlog.json", result)
    _check_validated_commands(handoff, result, policy=pol)
    _check_forensics(run_dir, state, result, policy=pol)

    return result


def _check_completion_requirements(
    state: Any,
    findings: list[Any],
    backlog: list[Any],
    result: ValidationResult,
    *,
    policy: ValidatorPolicy,
) -> None:
    if not isinstance(state, dict):
        return
    history = state.get("open_issue_count_history", [])
    status = state.get("status")
    pass_count = state.get("pass_count", 0)
    open_findings = [
        item for item in findings
        if isinstance(item, dict) and item.get("status") not in CLOSED_STATUSES
    ]
    open_backlog = [
        item for item in backlog
        if isinstance(item, dict) and item.get("state") not in CLOSED_STATUSES
    ]

    if isinstance(status, str) and status == "complete":
        if not isinstance(pass_count, int) or pass_count < 2:
            result.failures.append("Completed run must include at least two passes")
        if not state.get("fresh_confirmation_pass_done", False):
            result.failures.append("Completed run must include confirmation pass")
        if not isinstance(history, list) or not history:
            result.failures.append("Completed run must include a non-empty pass history")
        elif 0 not in history:
            result.failures.append("Completed run must include a zero-issue pass")
        if open_findings:
            result.failures.append("Completed run must not keep open current-pass findings")
        if open_backlog:
            result.failures.append("Completed run must not keep open backlog issues")
        # Confirmation pass must be the latest pass
        if (
            isinstance(history, list) and history
            and history[-1] == 0
            and state.get("fresh_confirmation_pass_done", False)
        ):
            latest_pass_id = state.get("latest_pass_id")
            if not (isinstance(latest_pass_id, str) and latest_pass_id):
                result.failures.append("confirmation pass must be the latest pass")
            else:
                low = latest_pass_id.lower()
                if "confirm" not in low and not low.endswith(("final", "summary")):
                    result.failures.append(
                        "confirmation pass must be the latest pass"
                    )

    if isinstance(history, list) and len(history) >= 3 and history[-1] >= history[-2] >= history[-3]:
        result.failures.append("open issue count is non-decreasing for 2 consecutive loops")


def _check_history_invariants(
    state: Any, result: ValidationResult, *, policy: ValidatorPolicy
) -> None:
    if not isinstance(state, dict):
        return
    history = state.get("open_issue_count_history", [])
    pass_count = state.get("pass_count", 0)
    if isinstance(history, list) and isinstance(pass_count, int):
        if len(history) != pass_count:
            result.failures.append(
                f"pass history length ({len(history)}) does not match pass_count ({pass_count})"
            )
    latest_zero = state.get("latest_zero_issue_pass_id")
    has_zero = isinstance(history, list) and 0 in history
    if latest_zero is not None and not has_zero:
        result.failures.append("latest_zero_issue_pass_id set without 0 in history")
    elif latest_zero is None and has_zero and state.get("status") == "complete":
        result.failures.append("history contains 0 but latest_zero_issue_pass_id is null")


def _check_issue_id_sets(
    state: Any, result: ValidationResult, *, policy: ValidatorPolicy
) -> None:
    if not isinstance(state, dict):
        return
    open_ids = state.get("open_issue_ids") or []
    closed_ids = state.get("closed_issue_ids") or []
    if not isinstance(open_ids, list) or not isinstance(closed_ids, list):
        return
    open_set = {x for x in open_ids if isinstance(x, str)}
    closed_set = {x for x in closed_ids if isinstance(x, str)}
    overlap = open_set & closed_set
    for issue_id in sorted(overlap):
        result.failures.append(
            f"issue_id {issue_id} appears in both open_issue_ids and closed_issue_ids"
        )
    # Warning: reconcile with history tail
    history = state.get("open_issue_count_history", [])
    if isinstance(history, list) and history and state.get("status") == "complete":
        expected_open = history[-1]
        actual_open = len(open_set)
        if actual_open != expected_open:
            result.warnings.append(
                f"open/closed counts and history tail do not reconcile (warning): "
                f"history_tail={expected_open}, open_issue_ids={actual_open}"
            )


def _check_finding_backlog_consistency(
    findings: list[Any],
    backlog: list[Any],
    result: ValidationResult,
    *,
    policy: ValidatorPolicy,
) -> None:
    if not isinstance(findings, list) or not isinstance(backlog, list):
        return
    backlog_by_id: dict[str, dict] = {}
    for item in backlog:
        if not isinstance(item, dict):
            continue
        issue_id = item.get("issue_id")
        if isinstance(issue_id, str) and issue_id:
            backlog_by_id[issue_id] = item

    seen = set()
    for finding in findings:
        if not isinstance(finding, dict):
            result.failures.append(
                "review-current-pass-findings.json: finding is not an object"
            )
            continue
        issue_id = finding.get("issue_id")
        if not isinstance(issue_id, str) or not issue_id:
            continue
        if issue_id in seen:
            result.failures.append(
                f"review-current-pass-findings.json: duplicate issue_id {issue_id}"
            )
        seen.add(issue_id)

        if finding.get("status") in CLOSED_STATUSES and not finding.get("evidence_after"):
            result.failures.append(
                f"{issue_id}: closed item missing evidence_after"
            )

        if issue_id not in backlog_by_id:
            result.failures.append(
                f"finding {issue_id} has no matching backlog entry"
            )
            continue

        backlog_item = backlog_by_id[issue_id]
        backlog_state = backlog_item.get("state")
        finding_status = finding.get("status")
        if isinstance(backlog_state, str) and isinstance(finding_status, str):
            if backlog_state in CLOSED_STATUSES and finding_status not in CLOSED_STATUSES:
                result.failures.append(
                    f"backlog state vs finding status mismatch for {issue_id}: "
                    f"backlog={backlog_state!r} finding={finding_status!r}"
                )
            elif backlog_state in OPEN_STATUSES and finding_status not in OPEN_STATUSES:
                result.failures.append(
                    f"backlog state vs finding status mismatch for {issue_id}: "
                    f"backlog={backlog_state!r} finding={finding_status!r}"
                )

    # Backlog-level: state must be a valid enum, and closed entries need
    # evidence_after
    seen_backlog = set()
    for item in backlog:
        if not isinstance(item, dict):
            result.failures.append(
                "review-live-backlog.json: backlog item is not an object"
            )
            continue
        issue_id = item.get("issue_id")
        if not isinstance(issue_id, str) or not issue_id:
            continue
        if issue_id in seen_backlog:
            result.failures.append(
                f"review-live-backlog.json: duplicate issue_id {issue_id}"
            )
        seen_backlog.add(issue_id)
        state_value = item.get("state")
        if isinstance(state_value, str):
            if state_value not in policy.state_enum_backlog:
                result.failures.append(
                    f"{issue_id}: invalid backlog state {state_value!r}"
                )
            if state_value in CLOSED_STATUSES and not item.get("evidence_after"):
                result.failures.append(
                    f"{issue_id}: closed backlog item missing evidence_after"
                )


def _check_files_uniqueness(
    items: list[Any], source_name: str, result: ValidationResult
) -> None:
    if not isinstance(items, list):
        return
    for item in items:
        if not isinstance(item, dict):
            continue
        issue_id = item.get("issue_id") or "<unknown>"
        files = item.get("files")
        if isinstance(files, list):
            seen_paths = set()
            for f in files:
                if not isinstance(f, str):
                    continue
                if f in seen_paths:
                    result.failures.append(
                        f"{issue_id}: lists the same file path twice"
                    )
                    break
                seen_paths.add(f)


def _check_validated_commands(
    handoff: Any, result: ValidationResult, *, policy: ValidatorPolicy
) -> None:
    if not isinstance(handoff, dict):
        return
    cmds = handoff.get("validated_commands")
    if not isinstance(cmds, list):
        return
    for cmd in cmds:
        if not isinstance(cmd, str) or not cmd.strip():
            continue
        stripped = cmd.lstrip()
        first_token = stripped.split()[0] if stripped else ""
        # Match if the command's first whitespace-separated token equals a
        # prefix exactly, OR the command starts with a prefix followed by
        # whitespace (or is exactly the prefix). This lets `npm test` match
        # the `npm test` prefix even when no args follow.
        if not any(
            first_token == prefix
            or stripped == prefix
            or stripped.startswith(prefix + " ")
            for prefix in policy.validated_command_prefixes
        ):
            result.failures.append(
                f"validated_commands contains unrunnable entry {cmd!r}"
            )


def _check_forensics(
    run_dir: Path, state: Any, result: ValidationResult, *, policy: ValidatorPolicy
) -> None:
    if not isinstance(state, dict):
        return
    status = state.get("status")
    forensics_path = run_dir / "forensics.md"
    has_forensics = forensics_path.exists()
    if isinstance(status, str) and status in {"stalled", "failed"}:
        if not has_forensics:
            result.failures.append(
                f"stalled/failed run must include forensics.md (status={status!r})"
            )
    elif has_forensics:
        result.failures.append(
            f"forensics.md present on non-stalled run (status={status!r})"
        )


# =============================================================================
# CLI
# =============================================================================

USAGE_TEXT = f"""Usage: validate_review_artifacts.py [options] <run-dir>

Validates a vnpt-review-orchestrator run directory.

Options:
  --help, -h           Print this help and exit 0.
  --version            Print version and exit 0.
  --strict             Promote warnings to failures.
  --config <path>      Load validator policy from a custom guardrails YAML.
  --quiet, -q          Suppress the JSON PASS line; still exit 0/1.
  --diff               (Forward-looking) emit a unified-diff style report of
                       recommended edits; not yet implemented for P0.

Exit codes:
  0  PASS
  1  FAIL  (one or more validation failures, or --strict promoted warnings)
  2  Usage error  (no args, missing run dir, malformed REQUIRED JSON)
  3  Internal error

Enforced rule groups (full list in docs/VALIDATOR_REFERENCE.md):
  - required artifacts       (5 .md + 3 .md-required .json + 3 contract files)
  - markdown sections/tables (line-anchored, column-anchored)
  - placeholder policy       (TODO/TBD/FIXME/XXX/lorem ipsum/... in MD bodies,
                              exempt inside fenced code blocks)
  - JSON schema enforcement (severity/category/state/status/mode/scope_source
                              enums; minItems/minLength/required/additional)
  - status invariants        (closed needs evidence_after; open backlog not
                              kept on completed runs; non-decreasing history
                              for 2 consecutive loops)
  - cross-file invariants    (history length == pass_count; 0 in history iff
                              latest_zero_issue_pass_id set; open/closed
                              disjoint; finding ↔ backlog reconciliation;
                              confirmation pass is the latest; forensics iff
                              stalled/failed; duplicate paths inside items;
                              validated_commands starts with a runnable prefix)
  - CLI / exit code matrix   (0/1/2/3; --strict, --quiet, --config, --help,
                              --version; malformed REQUIRED JSON → exit 2)
"""


def _build_argparser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="validate_review_artifacts.py",
        description="Strict validator for vnpt-review-orchestrator run artifacts.",
        add_help=False,  # we print our own --help
    )
    parser.add_argument("--help", "-h", action="store_true", dest="help")
    parser.add_argument("--version", action="store_true", dest="version")
    parser.add_argument("--strict", action="store_true", dest="strict")
    parser.add_argument("--config", dest="config", default=None)
    parser.add_argument("--quiet", "-q", action="store_true", dest="quiet")
    parser.add_argument("--diff", action="store_true", dest="diff")
    parser.add_argument("run_dir", nargs="?")
    return parser


def main(argv: Optional[list[str]] = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    # Windows consoles default to cp1252; USAGE_TEXT contains non-ASCII
    # arrows/dashes. Reconfigure stdout/stderr to UTF-8 so --help and the
    # PASS/FAIL JSON dump do not crash on Unicode.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, OSError):
            pass
    parser = _build_argparser()
    args = parser.parse_args(argv)

    if args.help:
        print(USAGE_TEXT)
        return 0
    if args.version:
        print(f"vnpt-review-orchestrator validate_review_artifacts.py {VERSION}")
        return 0

    if not args.run_dir:
        print(USAGE_TEXT, file=sys.stderr)
        return 2

    if args.diff:
        sys.stderr.write(
            "ERROR: --diff is a forward-looking placeholder; "
            "no P0 behavior is implemented yet.\n"
        )
        # Don't fail the run; just report and continue with normal validation.
        # Strict mode would still allow the user to opt out of this in future.

    run_dir = Path(args.run_dir).resolve()
    if not run_dir.exists():
        sys.stderr.write(f"ERROR: run directory not found: {run_dir}\n")
        return 2
    if not run_dir.is_dir():
        sys.stderr.write(f"ERROR: not a directory: {run_dir}\n")
        return 2

    config_path: Optional[Path] = None
    if args.config:
        config_path = Path(args.config).resolve()
        if not config_path.exists():
            sys.stderr.write(f"ERROR: --config file not found: {config_path}\n")
            return 2
    else:
        default_config = bundle_root() / "config" / "medium-model-guardrails.yaml"
        if default_config.exists():
            config_path = default_config

    policy = load_policy(config_path)
    if args.strict:
        policy.strict_mode_default = True

    try:
        result = validate_artifacts(run_dir, policy=policy)
    except RequiredJsonError as exc:
        sys.stderr.write(f"ERROR: {exc}\n")
        return 2
    except Exception as exc:  # pragma: no cover - belt and suspenders
        sys.stderr.write(f"INTERNAL ERROR: {exc}\n")
        return 3

    # --strict: promote warnings to failures
    if args.strict:
        result.failures.extend(result.warnings)
        result.warnings = []

    if result.failures:
        print(
            json.dumps(
                {
                    "status": "FAIL",
                    "run_dir": str(run_dir),
                    "strict": bool(args.strict),
                    "failures": result.failures,
                    "warnings": result.warnings,
                },
                indent=2,
            )
        )
        return 1
    if args.quiet:
        return 0
    print(
        json.dumps(
            {
                "status": "PASS",
                "run_dir": str(run_dir),
                "strict": bool(args.strict),
                "warnings": result.warnings,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
