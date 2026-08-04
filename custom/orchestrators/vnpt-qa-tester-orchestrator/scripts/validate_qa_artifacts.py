#!/usr/bin/env python3
"""Strict artifact validator for vnpt-qa-tester-orchestrator.

This catches common mid-tier model failures: missing artifacts, placeholders,
missing traceability, automation before oracle, shallow-test language, and missing
recursive BMAD docs discovery proof.

Usage:
  python scripts/validate_qa_artifacts.py docs/qa/<feature>
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path
from typing import Optional

from shared_utils import (
    read, batch_read,  # File utilities
    TEST_ID_RE, RISK_RE, ORACLE_RE, GAP_LABELS,  # Regex patterns & constants
    TRACEABILITY_SCOPE_CHARS, RISK_CONTEXT_WINDOW, GAP_CONTEXT_CHARS,  # Window sizes
    ALL_BUG_TYPES,  # Bug types from schema
    validate_fix_briefs_dir, validate_bmad_proof, extract_test_blocks,  # Shared validation
)

# Keep local constants only
REQUIRED = [
    "00-qa-mission.md", "01-context-map.md", "02-risk-map.md", "03-test-strategy.md",
    "04a-example-test-cases.md", "04b-combinatorial-dimensions.md", "04c-pict-model.pict",
    "04d-combinatorial-test-matrix.md", "04e-state-model.md", "04f-state-sequence-tests.md",
    "04g-property-invariants.md", "04h-api-fuzz-plan.md", "04i-exploratory-charter.md",
    "04j-regression-test-plan.md", "04k-test-data-fixtures.md", "05-test-oracle.md",
    "06-automation-map.md", "07-test-execution-report.md", "08-failure-triage.md",
    "09-fix-briefs", "10-quality-gate-report.md", "11-final-qa-report.md",
]
PLACEHOLDERS = ["TODO", "TBD", "Fill with project-specific", "lorem ipsum", "placeholder"]
SHALLOW_MARKERS = ["render", "status 200", "snapshot", "should work", "happy path only"]


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: validate_qa_artifacts.py docs/qa/<feature>", file=sys.stderr)
        return 2
    qa = Path(sys.argv[1]).resolve()
    failures = []
    warnings = []

    # Batch read all required files at once (avoid duplicate reads)
    artifact_cache = batch_read(qa, [f for f in REQUIRED if f != "09-fix-briefs"])
    all_text = "\n".join(artifact_cache.values())
    context_text = artifact_cache.get("01-context-map.md", "")

    for f in REQUIRED:
        p = qa / f
        text = artifact_cache.get(f, "").strip() if f != "09-fix-briefs" else ""
        if not p.exists() and f != "09-fix-briefs":
            failures.append(f"Missing artifact: {f}")
            continue
        if f.endswith(".md") and len(text) < 120:
            failures.append(f"Artifact too shallow: {f}")
        if any(ph.lower() in text.lower() for ph in PLACEHOLDERS):
            failures.append(f"Placeholder remains in artifact: {f}")

    # Use shared BMAD proof validation
    bmad_failures = validate_bmad_proof(context_text)
    failures.extend(bmad_failures)

    oracle_text = artifact_cache.get("05-test-oracle.md", "")
    automation_text = artifact_cache.get("06-automation-map.md", "")
    if automation_text and not ORACLE_RE.search(oracle_text):
        failures.append("Automation exists but no ORACLE-* IDs found in 05-test-oracle.md")

    if not TEST_ID_RE.search(all_text):
        failures.append("No stable QA-* test IDs found")
    if not RISK_RE.search(all_text):
        failures.append("No RISK-* IDs found")
    if not ORACLE_RE.search(all_text):
        failures.append("No ORACLE-* IDs found")

    shallow_hits = [m for m in SHALLOW_MARKERS if m in all_text.lower()]
    if shallow_hits and "business" not in all_text.lower() and "assert" not in all_text.lower():
        warnings.append(f"Possible shallow-test language without business assertions: {sorted(set(shallow_hits))}")

    qg = artifact_cache.get("10-quality-gate-report.md", "") + artifact_cache.get("11-final-qa-report.md", "")
    required_checks = ["P0", "P1", "negative", "boundary", "oracle", "triage"]
    for c in required_checks:
        if c.lower() not in qg.lower():
            failures.append(f"Quality/final report missing self-review topic: {c}")

    # === P0 NEW: Traceability check ===
    traceability_failures = check_traceability_triplet(all_text)
    failures.extend(traceability_failures)

    # === P0 NEW: P0 coverage check ===
    p0_coverage_failures = check_p0_coverage(all_text)
    failures.extend(p0_coverage_failures)

    # === P1 NEW: Artifact schema validation ===
    bug_batches_failures = check_bug_batches_schema(qa)
    failures.extend(bug_batches_failures)

    # === P1 NEW: Fix briefs check ===
    fix_briefs_failures = check_fix_briefs(qa)
    failures.extend(fix_briefs_failures)

    # === P2 NEW: Gap labels must have action plans ===
    gap_action_failures = check_gap_labels_action_plans(context_text, all_text)
    failures.extend(gap_action_failures)

    # === P2 NEW: Anti-gaming - duplicate test detection ===
    duplicate_failures = check_duplicate_tests(all_text)
    if duplicate_failures:
        warnings.extend(duplicate_failures)

    result = {"qa_dir": str(qa), "status": "FAIL" if failures else "PASS", "failures": failures, "warnings": warnings}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if failures else 0


# =============================================================================
# NEW: P0 - Traceability Check (test → risk → oracle)
# =============================================================================
def check_traceability_triplet(all_text: str) -> list[str]:
    """P0: Every test must map to risk_id AND oracle_id."""
    failures = []
    test_ids = TEST_ID_RE.findall(all_text)

    if not test_ids:
        return failures  # Already checked separately

    for test_id in test_ids:
        # Check if test has risk mapping
        risk_pattern = rf"{re.escape(test_id)}.*?risk[_-]?ids?\s*[:\-]\s*\[?(RISK-\d+[,\s]*)+"
        if not re.search(risk_pattern, all_text, re.IGNORECASE | re.DOTALL):
            # Try simpler pattern - use shared window constant
            test_pos = all_text.find(test_id)
            if test_pos != -1:
                nearby_text = all_text[test_pos:test_pos + TRACEABILITY_SCOPE_CHARS]
                if not RISK_RE.search(nearby_text):
                    failures.append(f"Test {test_id} has no risk_id mapping within scope")

        # Check if test has oracle mapping
        oracle_pattern = rf"{re.escape(test_id)}.*?oracle[_-]?ids?\s*[:\-]\s*\[?(ORACLE-\d+[,\s]*)+"
        if not re.search(oracle_pattern, all_text, re.IGNORECASE | re.DOTALL):
            test_pos = all_text.find(test_id)
            if test_pos != -1:
                nearby_text = all_text[test_pos:test_pos + TRACEABILITY_SCOPE_CHARS]
                if not ORACLE_RE.search(nearby_text):
                    failures.append(f"Test {test_id} has no oracle_id mapping within scope")

    return failures


# Note: _extract_test_blocks is now imported from shared_utils


# =============================================================================
# NEW: P0 - P0 Risk Coverage Check
# =============================================================================
def check_p0_coverage(all_text: str) -> list[str]:
    """P0: Per P0 risk must have >=1 happy + >=2 negative + >=2 boundary tests."""
    failures = []

    # Find all P0 risks
    p0_risks = _extract_p0_risks(all_text)

    if not p0_risks and RISK_RE.search(all_text):
        # No explicit P0 found, but risks exist - warn
        return failures  # Not a failure, risks may not be explicitly tagged P0

    for risk_id in p0_risks:
        tests_for_risk = _get_tests_for_risk(all_text, risk_id)

        # Count by type
        happy_count = _count_tests_by_type(tests_for_risk, ["happy", "main", "example", "positive"])
        negative_count = _count_tests_by_type(tests_for_risk, ["negative", "invalid", "error"])
        boundary_count = _count_tests_by_type(tests_for_risk, ["boundary", "edge", "limit"])

        if happy_count < 1:
            failures.append(f"P0 risk {risk_id} missing happy-path test (need >=1, found {happy_count})")
        if negative_count < 2:
            failures.append(f"P0 risk {risk_id} has only {negative_count} negative tests (need >=2)")
        if boundary_count < 2:
            failures.append(f"P0 risk {risk_id} has only {boundary_count} boundary tests (need >=2)")

    return failures


def _extract_p0_risks(text: str) -> list[str]:
    """Extract all P0 risk IDs from text using RISK_CONTEXT_WINDOW."""
    risk_ids = RISK_RE.findall(text)
    p0_risks = []

    for risk_id in risk_ids:
        # Look for P0 marker near the risk ID (within context window)
        risk_pos = text.find(risk_id)
        if risk_pos != -1:
            nearby = text[max(0, risk_pos - 200):min(len(text), risk_pos + RISK_CONTEXT_WINDOW)]
            if re.search(r"\bP0\b", nearby, re.IGNORECASE):
                p0_risks.append(risk_id)

    return p0_risks


def _get_tests_for_risk(text: str, risk_id: str) -> list[dict]:
    """Get all tests mapped to a specific risk."""
    tests = []

    # Find risk position
    risk_pos = text.find(risk_id)
    if risk_pos == -1:
        return tests

    # Look for tests that reference this risk
    # Scan forward from risk position
    search_end = min(len(text), risk_pos + 5000)
    segment = text[risk_pos:search_end]

    # Find test IDs in this segment
    for match in TEST_ID_RE.finditer(segment):
        test_id = match.group(0)
        if test_id not in [t["test_id"] for t in tests]:
            tests.append({"test_id": test_id, "text": segment[match.start():match.start() + 200]})

    return tests


def _count_tests_by_type(tests: list[dict], type_keywords: list[str]) -> int:
    """Count tests that match given type keywords in title or type field."""
    count = 0
    for test in tests:
        test_text_lower = test["text"].lower()
        for kw in type_keywords:
            if kw in test_text_lower:
                count += 1
                break
    return count


# =============================================================================
# NEW: P1 - Bug Batches Schema Validation
# =============================================================================
def check_bug_batches_schema(qa_dir: Path) -> list[str]:
    """Check bug-batches.json exists and is valid JSON."""
    failures = []
    bug_batches_file = qa_dir / "bug-batches.json"

    if not bug_batches_file.exists():
        # Only fail if failure triage exists (meaning bugs were found)
        triage_text = read(qa_dir / "08-failure-triage.md")
        if "PRODUCT_BUG" in triage_text or "TEST_BUG" in triage_text:
            failures.append("bug-batches.json missing but bugs exist in triage")
        return failures

    try:
        data = json.loads(bug_batches_file.read_text(encoding="utf-8"))

        # Check structure
        if "bugs" not in data:
            failures.append("bug-batches.json missing 'bugs' array")
            return failures

        # Validate each bug
        for i, bug in enumerate(data.get("bugs", [])):
            bug_id = bug.get("id", f"index_{i}")
            required_fields = ["id", "severity", "type", "summary", "risk_id", "failed_tests",
                              "reproduction_steps", "expected", "actual", "tests_to_rerun"]

            for field in required_fields:
                if field not in bug:
                    failures.append(f"Bug {bug_id} missing required field: {field}")

            # Check severity values
            valid_severities = ["P0", "P1", "P2", "P3"]
            if bug.get("severity") not in valid_severities:
                failures.append(f"Bug {bug_id} has invalid severity: {bug.get('severity')}")

            # Check type values (use constants from shared_utils)
            if bug.get("type") not in ALL_BUG_TYPES:
                failures.append(f"Bug {bug_id} has invalid type: {bug.get('type')}")

    except json.JSONDecodeError as e:
        failures.append(f"bug-batches.json is not valid JSON: {e}")

    return failures


# =============================================================================
# NEW: P1 - Fix Briefs Check
# =============================================================================
def check_fix_briefs(qa_dir: Path) -> list[str]:
    """Check that fix briefs exist for PRODUCT_BUG entries.

    Uses shared validation from shared_utils.validate_fix_briefs_dir().
    """
    triage_text = artifact_cache.get("08-failure-triage.md", "") if 'artifact_cache' in dir() else read(qa_dir / "08-failure-triage.md")

    # Count PRODUCT_BUG entries
    product_bugs = re.findall(r"PRODUCT_BUG", triage_text)

    if not product_bugs:
        return []  # No product bugs, no fix briefs needed

    # Use shared fix briefs validation
    fix_briefs_dir = qa_dir / "09-fix-briefs"
    failures = validate_fix_briefs_dir(fix_briefs_dir)

    # Check fix brief count matches product bugs
    if fix_briefs_dir.exists():
        fix_briefs = list(fix_briefs_dir.glob("*.md"))
        if len(fix_briefs) < len(product_bugs):
            failures.append(f"Fix briefs ({len(fix_briefs)}) less than PRODUCT_BUGs ({len(product_bugs)})")

    return failures


# =============================================================================
# NEW: P2 - Gap Labels Must Have Action Plans
# =============================================================================
def check_gap_labels_action_plans(context_text: str, all_text: str) -> list[str]:
    """Every gap label (SPEC_AMBIGUITY, ORACLE_GAP, etc.) must have action plan or fallback.

    Uses GAP_CONTEXT_CHARS constant from shared_utils.
    """
    failures = []

    for label in GAP_LABELS:
        # Find all occurrences of gap label
        pattern = rf"\b{label}\b"
        matches = list(re.finditer(pattern, all_text, re.IGNORECASE))

        for match in matches:
            pos = match.start()
            # Check within context window if there's an action/fallback mentioned
            context = all_text[pos:pos + GAP_CONTEXT_CHARS].lower()

            # Acceptable follow-ups
            has_action = any(kw in context for kw in [
                "fallback", "manual", "exploratory", "justified", "skip",
                "alternative", "plan", "mitigation", "workaround"
            ])

            # Also accept if it's explicitly marked as documented exception
            if "documented" in context or "recorded" in context:
                has_action = True

            if not has_action:
                failures.append(f"{label} found at position {pos} without action plan or fallback")

    return failures


# =============================================================================
# NEW: P2 - Duplicate Test Detection
# =============================================================================
def check_duplicate_tests(all_text: str) -> list[str]:
    """Detect potentially duplicate test cases."""
    warnings = []

    test_blocks = _extract_test_blocks(all_text)
    duplicates = []

    for i, block1 in enumerate(test_blocks):
        for block2 in test_blocks[i + 1:]:
            similarity = _calculate_test_similarity(block1, block2)
            if similarity > 0.85:  # 85% similarity threshold
                duplicates.append((block1["test_id"], block2["test_id"], similarity))

    for dup in duplicates:
        warnings.append(f"Potential duplicate test pair: {dup[0]} and {dup[1]} (similarity: {dup[2]:.2f})")

    return warnings


def _calculate_test_similarity(block1: dict, block2: dict) -> float:
    """Calculate similarity between two test blocks based on title and expected result."""
    text1 = block1["text"].lower()
    text2 = block2["text"].lower()

    # Extract title (first line with # or title: pattern)
    title1 = re.search(r"(?:^#+\s*[^\n]+\n|^title:\s*[^\n]+)", text1, re.MULTILINE)
    title2 = re.search(r"(?:^#+\s*[^\n]+\n|^title:\s*[^\n]+)", text2, re.MULTILINE)

    title1_str = title1.group(0) if title1 else ""
    title2_str = title2.group(0) if title2 else ""

    # Extract expected result
    expected1 = re.search(r"expected[_-]?result:\s*[^\n]+", text1, re.IGNORECASE)
    expected2 = re.search(r"expected[_-]?result:\s*[^\n]+", text2, re.IGNORECASE)

    expected1_str = expected1.group(0) if expected1 else ""
    expected2_str = expected2.group(0) if expected2 else ""

    # Simple Jaccard similarity on key tokens
    tokens1 = set(re.findall(r"\b\w+\b", title1_str + expected1_str))
    tokens2 = set(re.findall(r"\b\w+\b", title2_str + expected2_str))

    if not tokens1 or not tokens2:
        return 0.0

    intersection = len(tokens1 & tokens2)
    union = len(tokens1 | tokens2)

    return intersection / union if union > 0 else 0.0


if __name__ == "__main__":
    raise SystemExit(main())
