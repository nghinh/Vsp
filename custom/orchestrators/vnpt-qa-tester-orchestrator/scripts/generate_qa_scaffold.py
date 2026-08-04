#!/usr/bin/env python3
"""Create the standard docs/qa/<feature> artifact scaffold.

Usage:
  python scripts/generate_qa_scaffold.py <project-root> <feature-name>
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ARTIFACTS = [
    "00-qa-mission.md",
    "01-context-map.md",
    "02-risk-map.md",
    "03-test-strategy.md",
    "04a-example-test-cases.md",
    "04b-combinatorial-dimensions.md",
    "04c-pict-model.pict",
    "04d-combinatorial-test-matrix.md",
    "04e-state-model.md",
    "04f-state-sequence-tests.md",
    "04g-property-invariants.md",
    "04h-api-fuzz-plan.md",
    "04i-exploratory-charter.md",
    "04j-regression-test-plan.md",
    "04k-test-data-fixtures.md",
    "05-test-oracle.md",
    "06-automation-map.md",
    "07-test-execution-report.md",
    "08-failure-triage.md",
    "10-quality-gate-report.md",
    "11-final-qa-report.md",
    "12-qa-self-review.md",
    "ambiguity-log.md",
    "test-id-registry.md",
]


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: generate_qa_scaffold.py <project-root> <feature-name>", file=sys.stderr)
        return 2

    project_root = Path(sys.argv[1]).resolve()
    feature = sys.argv[2].strip().replace(" ", "-")
    out = project_root / "docs" / "qa" / feature
    out.mkdir(parents=True, exist_ok=True)
    (out / "09-fix-briefs").mkdir(exist_ok=True)

    for artifact in ARTIFACTS:
        p = out / artifact
        if not p.exists():
            title = artifact.replace(".md", "").replace(".pict", "").replace("-", " ").title()
            p.write_text(f"# {title}: {feature}\n\nTODO: Fill with project-specific QA content.\n", encoding="utf-8")

    bug_batches = out / "bug-batches.json"
    if not bug_batches.exists():
        bug_batches.write_text('{\n  "bugs": []\n}\n', encoding="utf-8")

    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
