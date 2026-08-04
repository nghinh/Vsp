#!/usr/bin/env python3
"""Runtime checkpoint enforcement for QA orchestrator.

This script validates checkpoint definitions before QA progress continues.
It can be run standalone or integrated with the external runtime harness.

Usage:
  python scripts/run_checkpoints.py [CP-ID|all|--blocking] docs/qa/<feature>
  python scripts/run_checkpoints.py --list
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path
from typing import Optional

import yaml

from shared_utils import (
    read, batch_read,  # File utilities
    RISK_RE, TEST_ID_RE, ORACLE_RE,  # Regex patterns
    validate_fix_briefs_dir, validate_bmad_proof,  # Shared validation
)


def load_checkpoints() -> list[dict]:
    """Load checkpoint definitions from YAML."""
    from shared_utils import get_runtime_dir
    runtime_dir = get_runtime_dir()
    checkpoint_file = runtime_dir / "checkpoints" / "checkpoint_definitions.yaml"

    if not checkpoint_file.exists():
        print(f"Warning: {checkpoint_file} not found", file=sys.stderr)
        return []

    with open(checkpoint_file, encoding="utf-8") as f:
        data = yaml.safe_load(f)

    return data.get("checkpoints", [])


def run_checkpoint_cp01(qa_dir: Path) -> tuple[bool, list[str]]:
    """CP-01: Phase 1 Context Completion - BMAD docs 0-EOF proof."""
    context_map = read(qa_dir / "01-context-map.md")

    # Use shared BMAD proof validation
    failures = validate_bmad_proof(context_map)

    # Check scope relevance annotated
    if "Scope relevance" not in context_map:
        failures.append("01-context-map.md missing 'Scope relevance' column")

    return len(failures) == 0, failures


def run_checkpoint_cp02(qa_dir: Path) -> tuple[bool, list[str]]:
    """CP-02: Risk Map Completeness - P0/P1 risks have test strategy."""
    failures = []

    risk_map = read(qa_dir / "02-risk-map.md")

    # Check risk IDs exist using shared regex
    risk_ids = RISK_RE.findall(risk_map)
    if not risk_ids:
        failures.append("02-risk-map.md: No RISK-* IDs found")
        return False, failures

    # Check priority classification (P0/P1/P2/P3)
    priorities = re.findall(r"\bP[0-3]\b", risk_map)
    if not priorities:
        failures.append("02-risk-map.md: No priority classification (P0/P1/P2/P3) found")

    # Check test strategy column/mapping
    if "test strategy" not in risk_map.lower() and "strategy" not in risk_map.lower():
        failures.append("02-risk-map.md: No test strategy information found")

    return len(failures) == 0, failures


def run_checkpoint_cp03(qa_dir: Path) -> tuple[bool, list[str]]:
    """CP-03: Oracle Before Automation - Oracle exists for all tests."""
    failures = []

    oracle_text = read(qa_dir / "05-test-oracle.md")
    automation_text = read(qa_dir / "06-automation-map.md")

    # Check oracle IDs exist using shared regex
    oracle_ids = ORACLE_RE.findall(oracle_text)
    if not oracle_ids:
        failures.append("05-test-oracle.md: No ORACLE-* IDs found")

    # Check source column
    if "source" not in oracle_text.lower():
        failures.append("05-test-oracle.md: No source documentation found")

    # Check expected result specified
    if "expected" not in oracle_text.lower():
        failures.append("05-test-oracle.md: No expected result specification found")

    # Check forbidden result specified
    if "forbidden" not in oracle_text.lower():
        failures.append("05-test-oracle.md: No forbidden result specification found")

    # If automation exists, verify oracle exists
    if automation_text.strip() and not oracle_ids:
        failures.append("Automation exists but no oracles found - oracle must precede automation")

    return len(failures) == 0, failures


def run_checkpoint_cp04(qa_dir: Path) -> tuple[bool, list[str]]:
    """CP-04: Quality Gate Before Final Report - Hard fails passed."""
    failures = []

    quality_gate = read(qa_dir / "10-quality-gate-report.md")
    triage = read(qa_dir / "08-failure-triage.md")
    final_report = read(qa_dir / "11-final-qa-report.md")

    # Check hard fails passed
    if "hard fail" in quality_gate.lower() and "pass" not in quality_gate.lower():
        failures.append("10-quality-gate-report.md: Hard fails not passed")

    # Check P0 coverage
    if "P0" not in quality_gate:
        failures.append("10-quality-gate-report.md: P0 coverage not checked")

    # Check triage complete (no untriaged items)
    if "untriaged" in triage.lower() and "PRODUCT_BUG" in triage:
        failures.append("08-failure-triage.md: Found untriaged failures")

    # Check final report references quality gate
    if "quality gate" not in final_report.lower():
        failures.append("11-final-qa-report.md: Does not reference quality gate")

    return len(failures) == 0, failures


def run_checkpoint_cp05(qa_dir: Path) -> tuple[bool, list[str]]:
    """CP-05: Fix Briefs Validation - Fix briefs exist for PRODUCT_BUG.

    Uses shared validate_fix_briefs_dir() from shared_utils.
    """
    triage = read(qa_dir / "08-failure-triage.md")
    fix_briefs_dir = qa_dir / "09-fix-briefs"

    # Count PRODUCT_BUG entries
    product_bugs = re.findall(r"PRODUCT_BUG", triage)

    if not product_bugs:
        return True, []  # No product bugs, no fix briefs needed

    # Use shared fix briefs validation
    failures = validate_fix_briefs_dir(fix_briefs_dir)

    # Check fix brief count
    if fix_briefs_dir.exists():
        fix_briefs = list(fix_briefs_dir.glob("*.md"))
        if len(fix_briefs) < len(product_bugs):
            failures.append(f"Fix briefs ({len(fix_briefs)}) < PRODUCT_BUGs ({len(product_bugs)})")

    return len(failures) == 0, failures


CHECKPOINT_HANDLERS = {
    "CP-01": run_checkpoint_cp01,
    "CP-02": run_checkpoint_cp02,
    "CP-03": run_checkpoint_cp03,
    "CP-04": run_checkpoint_cp04,
    "CP-05": run_checkpoint_cp05,
}


def run_checkpoint(checkpoint_id: str, qa_dir: Path) -> tuple[bool, list[str]]:
    """Run a single checkpoint."""
    handler = CHECKPOINT_HANDLERS.get(checkpoint_id)
    if not handler:
        return False, [f"Unknown checkpoint: {checkpoint_id}"]

    return handler(qa_dir)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: run_checkpoints.py [CP-ID|all|--blocking|--list] [docs/qa/<feature>]", file=sys.stderr)
        return 2

    args = sys.argv[1:]
    qa_dir = None

    # Parse arguments
    checkpoint_filter = None
    blocking_only = False
    list_only = False

    for arg in args:
        if arg == "--blocking":
            blocking_only = True
        elif arg == "--list":
            list_only = True
        elif arg.startswith("CP-") or arg == "all":
            checkpoint_filter = arg
        elif Path(arg).exists():
            qa_dir = Path(arg).resolve()

    # List checkpoints if requested
    if list_only:
        checkpoints = load_checkpoints()
        print("Available checkpoints:")
        for cp in checkpoints:
            blocking = "BLOCKING" if cp.get("blocking") else "non-blocking"
            print(f"  {cp['id']}: {cp['name']} [{blocking}]")
        print(f"\nTotal: {len(checkpoints)} checkpoints")
        return 0

    if not qa_dir:
        print("Error: QA directory not specified", file=sys.stderr)
        return 2

    if not qa_dir.exists():
        print(f"Error: QA directory does not exist: {qa_dir}", file=sys.stderr)
        return 2

    checkpoints = load_checkpoints()

    if not checkpoint_filter or checkpoint_filter == "all":
        to_run = checkpoints
    else:
        to_run = [cp for cp in checkpoints if cp["id"] == checkpoint_filter]
        if not to_run:
            print(f"Error: Checkpoint {checkpoint_filter} not found", file=sys.stderr)
            return 1

    # Filter blocking only if requested
    if blocking_only:
        to_run = [cp for cp in to_run if cp.get("blocking")]

    results = []
    blocking_failures = []

    for cp in to_run:
        passed, failures = run_checkpoint(cp["id"], qa_dir)

        result = {
            "id": cp["id"],
            "name": cp["name"],
            "blocking": cp.get("blocking", False),
            "passed": passed,
            "failures": failures,
        }
        results.append(result)

        if not passed and cp.get("blocking"):
            blocking_failures.append(cp["id"])

    # Output results
    print(json.dumps({
        "qa_dir": str(qa_dir),
        "results": results,
        "summary": {
            "total": len(results),
            "passed": sum(1 for r in results if r["passed"]),
            "failed": sum(1 for r in results if not r["passed"]),
            "blocking_failed": blocking_failures,
        }
    }, ensure_ascii=False, indent=2))

    # Return exit code based on blocking failures
    if blocking_failures:
        print(f"\nBlocking checkpoint(s) failed: {', '.join(blocking_failures)}")
        print("Progress is blocked. Fix failures before continuing.")
        return 1

    if any(not r["passed"] for r in results):
        print("\nNon-blocking checkpoint(s) failed. Review warnings.")
        return 0

    print("\nAll checkpoints passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())