#!/usr/bin/env python3
"""Detect and run a mutation testing command when available.

Usage:
  python scripts/run_mutation_gate.py /path/to/project docs/qa/feature/mutation-report.md
"""
from __future__ import annotations
import shutil
import subprocess
import sys
from pathlib import Path


def choose_command(root: Path):
    if (root / 'package.json').exists() and shutil.which('npx'):
        return ['npx', 'stryker', 'run']
    if (root / 'pom.xml').exists() and shutil.which('mvn'):
        return ['mvn', 'test-compile', 'org.pitest:pitest-maven:mutationCoverage']
    if ((root / 'pyproject.toml').exists() or (root / 'requirements.txt').exists()) and shutil.which('mutmut'):
        return ['mutmut', 'run']
    return None


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    report = Path(sys.argv[2] if len(sys.argv) > 2 else 'mutation-gate-report.md')
    report.parent.mkdir(parents=True, exist_ok=True)
    cmd = choose_command(root)
    if not cmd:
        report.write_text('# Mutation Gate Report\n\nNo supported mutation command detected. Create a manual mutation plan for critical business logic.\n', encoding='utf-8')
        return 0
    proc = subprocess.run(cmd, cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    report.write_text('# Mutation Gate Report\n\nCommand:\n\n```bash\n%s\n```\n\nExit code: %s\n\n```text\n%s\n```\n' % (' '.join(cmd), proc.returncode, proc.stdout), encoding='utf-8')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
