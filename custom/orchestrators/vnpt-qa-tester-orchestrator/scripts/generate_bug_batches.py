#!/usr/bin/env python3
"""Generate an empty bug-batches.json skeleton.

Usage:
  python scripts/generate_bug_batches.py <feature> <output-json>
"""
from __future__ import annotations
import datetime as dt
import json
import sys
from pathlib import Path


def main():
    feature = sys.argv[1] if len(sys.argv) > 1 else 'feature'
    output = Path(sys.argv[2] if len(sys.argv) > 2 else 'bug-batches.json')
    data = {
        'feature': feature,
        'generated_at': dt.datetime.now(dt.timezone.utc).isoformat(),
        'bugs': []
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
