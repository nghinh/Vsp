#!/usr/bin/env python3
"""Decision-request review trigger for QA orchestrator.

This script checks if decision request is required based on decision-request trigger conditions
and generates review requests for the runtime harness.

Usage:
  python scripts/run_decision_request_review.py docs/qa/<feature>
  python scripts/run_decision_request_review.py docs/qa/<feature> --trigger decision-request-01
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path
from datetime import datetime

import yaml

from shared_utils import (
    read,  # File utilities
    get_runtime_dir,  # Path utilities
    SECURITY_BUG_TYPES, CONCURRENCY_BUG_TYPES,  # Bug type constants
    has_product_bug_with_fix_brief,  # Shared validation
)


def load_decision_request_triggers() -> list[dict]:
    """Load decision-request trigger definitions from YAML."""
    runtime_dir = get_runtime_dir()
    trigger_file = runtime_dir / "decision_requests" / "decision_request_triggers.yaml"

    if not trigger_file.exists():
        print(f"Warning: {trigger_file} not found", file=sys.stderr)
        return []

    with open(trigger_file, encoding="utf-8") as f:
        data = yaml.safe_load(f)

    return data.get("decision_request_required_when", [])


def check_trigger_decision_request01_p0_bug(qa_dir: Path) -> tuple[bool, str, list[str]]:
    """decision-request-01: P0 Bug Found - requires fix brief approval.

    Uses shared has_product_bug_with_fix_brief() from shared_utils.
    """
    triage = read(qa_dir / "08-failure-triage.md")
    fix_briefs_dir = qa_dir / "09-fix-briefs"

    # Use shared function for bug detection
    if not has_product_bug_with_fix_brief(triage, fix_briefs_dir):
        return False, "", []

    if fix_briefs_dir.exists():
        fix_briefs = list(fix_briefs_dir.glob("*.md"))
        if fix_briefs:
            return True, "P0 PRODUCT_BUG found with fix briefs", [f.name for f in fix_briefs]

    return True, "P0 PRODUCT_BUG found, fix briefs needed", []


def check_trigger_decision_request02_security(qa_dir: Path) -> tuple[bool, str, list[str]]:
    """decision-request-02: Security Issue Found - requires classification review.

    Uses SECURITY_BUG_TYPES from shared_utils.
    """
    triage = read(qa_dir / "08-failure-triage.md")

    # Find security bug types using shared constants
    security_bugs = [bug_type for bug_type in SECURITY_BUG_TYPES if bug_type in triage]

    if security_bugs:
        return True, f"Security issues found: {', '.join(security_bugs)}", security_bugs

    return False, "", []


def check_trigger_decision_request03_exploratory(qa_dir: Path) -> tuple[bool, str, list[str]]:
    """decision-request-03: Exploratory Test Planned - requires charter review."""
    charter = read(qa_dir / "04i-exploratory-charter.md")
    context = read(qa_dir / "01-context-map.md")

    # Check for exploratory test markers
    if "QA-EXP" in context or "exploratory" in charter.lower():
        return True, "Exploratory tests planned", []

    return False, "", []


def check_trigger_decision_request04_risk_change(qa_dir: Path) -> tuple[bool, str, list[str]]:
    """decision-request-04: Risk Model Significant Change - requires review."""
    risk_map = read(qa_dir / "02-risk-map.md")

    # Count risk IDs as proxy for model size
    risk_count = len(re.findall(r"RISK-\d{3}", risk_map))

    if risk_count > 20:
        return True, f"Large risk model detected ({risk_count} risks)", [f"risk_count={risk_count}"]

    return False, "", []


def check_trigger_decision_request05_conditional(qa_dir: Path) -> tuple[bool, str, list[str]]:
    """decision-request-05: Conditional Quality Gate - score 70-84%."""
    quality_gate = read(qa_dir / "10-quality-gate-report.md")

    # Look for conditional pass indicators
    if "conditional" in quality_gate.lower() or ("70" in quality_gate and "84" in quality_gate):
        return True, "Conditional quality gate score (70-84%)", []

    return False, "", []


def check_trigger_decision_request06_untriaged(qa_dir: Path) -> tuple[bool, str, list[str]]:
    """decision-request-06: Untriaged Failure - requires completion."""
    triage = read(qa_dir / "08-failure-triage.md")

    if "untriaged" in triage.lower() and ("PRODUCT_BUG" in triage or "TEST_BUG" in triage):
        untriaged_count = len(re.findall(r"untriaged", triage, re.IGNORECASE))
        return True, f"Found {untriaged_count} untriaged failures", []

    return False, "", []


def check_trigger_decision_request07_concurrency(qa_dir: Path) -> tuple[bool, str, list[str]]:
    """decision-request-07: Concurrency/State Bug - requires fix brief approval.

    Uses CONCURRENCY_BUG_TYPES from shared_utils.
    """
    triage = read(qa_dir / "08-failure-triage.md")

    # Find concurrency bug types using shared constants
    found_bugs = [bug_type for bug_type in CONCURRENCY_BUG_TYPES if bug_type in triage]

    if found_bugs:
        return True, f"Concurrency/state bugs found: {', '.join(found_bugs)}", found_bugs

    return False, "", []


TRIGGER_HANDLERS = {
    "decision-request-01": check_trigger_decision_request01_p0_bug,
    "decision-request-02": check_trigger_decision_request02_security,
    "decision-request-03": check_trigger_decision_request03_exploratory,
    "decision-request-04": check_trigger_decision_request04_risk_change,
    "decision-request-05": check_trigger_decision_request05_conditional,
    "decision-request-06": check_trigger_decision_request06_untriaged,
    "decision-request-07": check_trigger_decision_request07_concurrency,
}


def check_trigger(trigger_id: str, qa_dir: Path) -> tuple[bool, str, list[str]]:
    """Check a specific trigger."""
    handler = TRIGGER_HANDLERS.get(trigger_id)
    if not handler:
        return False, f"Unknown trigger: {trigger_id}", []

    return handler(qa_dir)


def generate_decision_request(trigger: dict, message: str, artifacts: list[str]) -> dict:
    """Generate decision-request artifact for runtime harness."""
    return {
        "contractVersion": "1.0.0",
        "producer": "vnpt-qa-tester-orchestrator",
        "producedAt": datetime.now().isoformat(),
        "decisionId": trigger["trigger_id"],
        "type": trigger.get("condition", {}).get("bug_type", "manual_review_required"),
        "title": trigger["name"],
        "message": message,
        "recommendedActions": trigger.get("required_response", "approve_continue").split(" | "),
        "artifacts": artifacts,
        "createdAt": datetime.now().isoformat(),
        "status": "pending"
    }


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: run_decision_request_review.py docs/qa/<feature> [--trigger decision-request-XX]", file=sys.stderr)
        return 2

    args = sys.argv[1:]
    qa_dir = None
    trigger_filter = None

    for arg in args:
        if arg.startswith("decision-request-"):
            trigger_filter = arg
        elif Path(arg).exists():
            qa_dir = Path(arg).resolve()

    if not qa_dir:
        print("Error: QA directory not specified", file=sys.stderr)
        return 2

    if not qa_dir.exists():
        print(f"Error: QA directory does not exist: {qa_dir}", file=sys.stderr)
        return 2

    triggers = load_decision_request_triggers()
    results = []
    triggered_review = []

    for trigger in triggers:
        trigger_id = trigger["trigger_id"]

        # Skip if filtering to specific trigger
        if trigger_filter and trigger_id != trigger_filter:
            continue

        # Check if trigger condition is met
        condition_met, message, artifacts = check_trigger(trigger_id, qa_dir)

        result = {
            "trigger_id": trigger_id,
            "name": trigger["name"],
            "condition_met": condition_met,
            "message": message,
            "artifacts": artifacts,
            "blocking": trigger.get("blocking", False),
        }
        results.append(result)

        if condition_met:
            triggered_review.append({
                "trigger": trigger,
                "message": message,
                "artifacts": artifacts,
            })

    # Generate decision request artifacts if triggered
    decision_requests = []
    for item in triggered_review:
        decision = generate_decision_request(item["trigger"], item["message"], item["artifacts"])
        decision_requests.append(decision)

    # Output results
    output = {
        "qa_dir": str(qa_dir),
        "evaluated_triggers": len(results),
        "triggered_count": len(triggered_review),
        "results": results,
    }

    if decision_requests:
        output["decision_requests"] = decision_requests
        output["decision_requests_file"] = str(qa_dir / ".runtime" / "current" / "decision-request.json")

    print(json.dumps(output, ensure_ascii=False, indent=2))

    # Write decision request file if triggered
    if decision_requests:
        runtime_current = qa_dir / ".runtime" / "current"
        runtime_current.mkdir(parents=True, exist_ok=True)

        decision_file = runtime_current / "decision-request.json"
        with open(decision_file, "w", encoding="utf-8") as f:
            json.dump(decision_requests[0], f, ensure_ascii=False, indent=2)

        print(f"\nDecision request written to: {decision_file}")
        print(f"Action required: {decision_requests[0]['recommendedActions']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
