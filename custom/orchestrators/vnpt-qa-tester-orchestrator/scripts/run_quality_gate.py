#!/usr/bin/env python3
"""Simple quality gate checker for docs/qa/<feature> artifacts.

This does not replace QA judgement. It catches missing required artifacts and
obvious anti-gaming problems.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REQUIRED = [
    "00-qa-mission.md",
    "01-context-map.md",
    "02-risk-map.md",
    "03-test-strategy.md",
    "04a-example-test-cases.md",
    "04b-combinatorial-dimensions.md",
    "04e-state-model.md",
    "04g-property-invariants.md",
    "04i-exploratory-charter.md",
    "04k-test-data-fixtures.md",
    "05-test-oracle.md",
    "06-automation-map.md",
    "07-test-execution-report.md",
    "08-failure-triage.md",
    "10-quality-gate-report.md",
    "11-final-qa-report.md",
]


def has_real_content(path: Path) -> bool:
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8", errors="ignore").strip()
    if len(text) < 80:
        return False
    shallow_markers = ["TODO: Fill with project-specific QA content"]
    return not any(marker in text for marker in shallow_markers)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: run_quality_gate.py <docs/qa/feature-dir>", file=sys.stderr)
        return 2

    qa_dir = Path(sys.argv[1]).resolve()
    failures = []
    for name in REQUIRED:
        if not has_real_content(qa_dir / name):
            failures.append(f"Missing or shallow artifact: {name}")

    oracle = qa_dir / "05-test-oracle.md"
    automation = qa_dir / "06-automation-map.md"
    if automation.exists() and not oracle.exists():
        failures.append("Automation exists but test oracle is missing")

    result = {
        "qa_dir": str(qa_dir),
        "status": "FAIL" if failures else "PASS",
        "failures": failures,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
