#!/usr/bin/env python3
"""Shared utilities for vnpt-qa-tester-orchestrator scripts.

This module provides common functions used across multiple scripts:
- File reading utilities
- Path utilities
- Constants and regex patterns
- Shared validation logic
"""
from __future__ import annotations
import re
from pathlib import Path
from typing import Optional

# =============================================================================
# Constants
# =============================================================================

# Traceability window sizes (chars)
TRACEABILITY_SCOPE_CHARS = 2000
RISK_CONTEXT_WINDOW = 500
GAP_CONTEXT_CHARS = 500

# Bug type constants (from bug-batches.schema.json)
CORE_BUG_TYPES = [
    "PRODUCT_BUG", "TEST_BUG", "FLAKY_TEST", "ENVIRONMENT_ISSUE",
    "SPEC_AMBIGUITY", "DATA_SETUP_ISSUE"
]

EXTENDED_BUG_TYPES = [
    "RACE_CONDITION", "SECURITY_ISSUE", "DEADLOCK_OR_LIVELOCK",
    "MEMORY_LEAK", "TIMING_ISSUE", "DATA_RACE", "ATOMICITY_VIOLATION",
    "ORDERING_VIOLATION", "CONSISTENCY_ISSUE", "IDEMPOTENCY_VIOLATION",
    "AUTHORIZATION_BYPASS", "INPUT_VALIDATION_BYPASS", "STATE_CORRUPTION"
]

ALL_BUG_TYPES = CORE_BUG_TYPES + EXTENDED_BUG_TYPES

SECURITY_BUG_TYPES = [
    "SECURITY_ISSUE", "AUTHORIZATION_BYPASS", "INPUT_VALIDATION_BYPASS"
]

CONCURRENCY_BUG_TYPES = [
    "RACE_CONDITION", "DEADLOCK_OR_LIVELOCK", "DATA_RACE",
    "ATOMICITY_VIOLATION", "ORDERING_VIOLATION", "STATE_CORRUPTION"
]

# Gap label constants
GAP_LABELS = ["SPEC_AMBIGUITY", "ORACLE_GAP", "ENV_GAP", "DATA_GAP", "TOOL_GAP", "JUSTIFIED_EXCEPTION"]

# Regex patterns
TEST_ID_RE = re.compile(r"QA-(EX|COMB|SM|PROP|API|E2E|REG|EXP)-\d{3}")
RISK_RE = re.compile(r"RISK-\d{3}")
ORACLE_RE = re.compile(r"ORACLE-\d{3}")

# =============================================================================
# File utilities
# =============================================================================

def read(path: Path) -> str:
    """Read file content safely, returns empty string if file doesn't exist.

    Args:
        path: Path to file to read

    Returns:
        File content as string, or empty string if file doesn't exist
    """
    return path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""


def batch_read(base_dir: Path, files: list[str]) -> dict[str, str]:
    """Read multiple files and return as dict.

    Args:
        base_dir: Base directory for files
        files: List of file paths relative to base_dir

    Returns:
        Dict mapping filename to content
    """
    return {f: read(base_dir / f) for f in files}


def read_multiple(base_dir: Path, files: list[str]) -> str:
    """Read multiple files and join with newlines.

    Args:
        base_dir: Base directory for files
        files: List of file paths relative to base_dir

    Returns:
        All file contents joined with newlines
    """
    return "\n".join(read(base_dir / f) for f in files)


# =============================================================================
# Path utilities
# =============================================================================

def get_runtime_dir() -> Path:
    """Get the runtime directory relative to this script.

    Returns:
        Path to runtime directory
    """
    return Path(__file__).parent.parent / "runtime"


def get_project_root() -> Path:
    """Get the project root directory.

    Returns:
        Path to project root
    """
    return Path(__file__).parent.parent


# =============================================================================
# Text analysis utilities
# =============================================================================

def find_nearby_ids(
    text: str,
    anchor_id: str,
    id_regex: re.Pattern,
    window_chars: int = TRACEABILITY_SCOPE_CHARS
) -> bool:
    """Check if an ID has a nearby matching ID within a text window.

    Args:
        text: Full text to search
        anchor_id: ID to find position of
        id_regex: Regex pattern for IDs to search for nearby
        window_chars: Number of chars to search around anchor

    Returns:
        True if anchor_id exists with nearby matching ID
    """
    pos = text.find(anchor_id)
    if pos == -1:
        return False

    start = max(0, pos - window_chars)
    end = min(len(text), pos + window_chars)
    nearby_text = text[start:end]

    return bool(id_regex.search(nearby_text))


def extract_test_blocks(text: str) -> list[tuple[str, str]]:
    """Extract test ID and nearby content blocks.

    Args:
        text: Text containing test IDs

    Returns:
        List of (test_id, block_content) tuples
    """
    blocks = []
    for match in TEST_ID_RE.finditer(text):
        test_id = match.group()
        pos = match.start()
        # Extract 500 chars around test ID
        start = max(0, pos - 200)
        end = min(len(text), pos + 300)
        blocks.append((test_id, text[start:end]))
    return blocks


# =============================================================================
# Shared validation logic
# =============================================================================

# Required sections for fix briefs
FIX_BRIEF_REQUIRED_SECTIONS = ["summary", "severity", "reproduction", "expected", "actual"]


def validate_fix_brief(content: str, filename: str) -> list[str]:
    """Validate a fix brief has all required sections.

    Args:
        content: Fix brief content
        filename: Filename for error messages

    Returns:
        List of failure messages (empty if valid)
    """
    failures = []
    for section in FIX_BRIEF_REQUIRED_SECTIONS:
        if section.lower() not in content.lower():
            failures.append(f"Fix brief {filename} missing section: {section}")
    return failures


def validate_fix_briefs_dir(fix_briefs_dir: Path) -> list[str]:
    """Validate all fix briefs in a directory.

    Args:
        fix_briefs_dir: Directory containing fix briefs

    Returns:
        List of failure messages
    """
    if not fix_briefs_dir.exists():
        return [f"Fix briefs directory not found: {fix_briefs_dir}"]

    failures = []
    fix_briefs = list(fix_briefs_dir.glob("*.md"))

    if not fix_briefs:
        return ["No fix briefs found in 09-fix-briefs directory"]

    for fb in fix_briefs:
        content = read(fb)
        failures.extend(validate_fix_brief(content, fb.name))

    return failures


def count_bugs_by_type(text: str, bug_types: list[str]) -> dict[str, int]:
    """Count occurrences of bug types in text.

    Args:
        text: Text to search
        bug_types: List of bug type strings to count

    Returns:
        Dict mapping bug type to count
    """
    counts = {}
    for bug_type in bug_types:
        counts[bug_type] = len(re.findall(bug_type, text))
    return counts


def has_product_bug_with_fix_brief(triage_text: str, fix_briefs_dir: Path) -> bool:
    """Check if triage contains PRODUCT_BUG with corresponding fix briefs.

    Args:
        triage_text: Content of failure-triage.md
        fix_briefs_dir: Directory containing fix briefs

    Returns:
        True if PRODUCT_BUG found with fix briefs
    """
    product_bugs = re.findall(r"PRODUCT_BUG", triage_text)
    if not product_bugs:
        return False

    if not fix_briefs_dir.exists():
        return False

    return len(list(fix_briefs_dir.glob("*.md"))) > 0


# =============================================================================
# BMAD validation utilities
# =============================================================================

BMAD_PROOF_MARKERS = [
    "BMAD Docs Inventory and 0-EOF Proof",
    "Discovery path",
]

RECURSIVE_SCAN_MARKERS = [
    "recursive", "docs/**", "recursive-docs-glob", "recursive-docs-fallback"
]

ZERO_EOF_PROOF_MARKERS = [
    "READ_0_EOF", "JUSTIFIED_EXCEPTION", "SPEC_AMBIGUITY"
]


def validate_bmad_proof(context_text: str) -> list[str]:
    """Validate BMAD 0-EOF proof requirements.

    Args:
        context_text: Content of context-map.md

    Returns:
        List of failure messages
    """
    failures = []

    for marker in BMAD_PROOF_MARKERS:
        if marker not in context_text:
            failures.append(f"01-context-map.md missing '{marker}' section")

    if not any(m.lower() in context_text.lower() for m in RECURSIVE_SCAN_MARKERS):
        failures.append("01-context-map.md does not prove recursive docs/** scan")

    if not any(m in context_text for m in ZERO_EOF_PROOF_MARKERS):
        failures.append("01-context-map.md lacks 0-EOF proof or documented exception")

    return failures