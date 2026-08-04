#!/usr/bin/env python3
"""Heuristic scorer for test-case depth.

Usage:
  python scripts/score_test_cases.py docs/qa/<feature>/04a-example-test-cases.md
"""
from __future__ import annotations
import json
import sys
from pathlib import Path

KEYS = {
    "negative": ["negative", "invalid", "reject", "forbidden", "error"],
    "boundary": ["boundary", "edge", "null", "empty", "zero", "maximum", "minimum", "off-by-one"],
    "state": ["state", "transition", "cancel", "retry", "timeout", "duplicate"],
    "oracle": ["expected", "forbidden", "assert", "oracle"],
    "traceability": ["risk-", "oracle-", "requirement", "qa-"],
}

def score(text: str) -> dict:
    lower = text.lower()
    result = {}
    total = 0
    for k, words in KEYS.items():
        hits = sum(1 for w in words if w in lower)
        val = min(20, hits * 5)
        result[k] = val
        total += val
    result["total"] = min(100, total)
    return result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: score_test_cases.py <test-case-md>", file=sys.stderr)
        raise SystemExit(2)
    text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
    print(json.dumps(score(text), ensure_ascii=False, indent=2))
