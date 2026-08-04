#!/usr/bin/env python3
"""Prepare or run Schemathesis API fuzzing.

Usage:
  python scripts/run_schemathesis.py openapi.yaml http://localhost:3000 docs/qa/feature/api-fuzz-report.md
"""
from __future__ import annotations
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 4:
        print('Usage: run_schemathesis.py <schema> <base_url> <report.md>', file=sys.stderr)
        return 2
    schema, base_url, report = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    report.parent.mkdir(parents=True, exist_ok=True)
    if not shutil.which('schemathesis'):
        report.write_text(f"""# API Fuzz Report\n\nSchemathesis is not installed.\n\nPlanned command:\n\n```bash\nschemathesis run {schema} --base-url {base_url}\n```\n""", encoding='utf-8')
        return 0
    cmd = ['schemathesis', 'run', str(schema), '--base-url', base_url]
    proc = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    report.write_text('# API Fuzz Report\n\nCommand:\n\n```bash\n%s\n```\n\nExit code: %s\n\n```text\n%s\n```\n' % (' '.join(cmd), proc.returncode, proc.stdout), encoding='utf-8')
    return proc.returncode

if __name__ == '__main__':
    raise SystemExit(main())
