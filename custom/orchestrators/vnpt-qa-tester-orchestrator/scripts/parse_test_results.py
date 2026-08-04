#!/usr/bin/env python3
"""Create a simple markdown test execution report from command output files.

Usage:
  python scripts/parse_test_results.py report.md command::exit_code::log_file [...]
"""
from __future__ import annotations
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print('Usage: parse_test_results.py report.md command::exit_code::log_file [...]', file=sys.stderr)
        return 2
    report = Path(sys.argv[1])
    lines = ['# Test Execution Report', '']
    for item in sys.argv[2:]:
        parts = item.split('::', 2)
        if len(parts) != 3:
            continue
        cmd, code, log_file = parts
        text = Path(log_file).read_text(encoding='utf-8', errors='ignore') if Path(log_file).exists() else ''
        lines += [f'## `{cmd}`', '', f'Exit code: `{code}`', '', '```text', text[-8000:], '```', '']
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text('\n'.join(lines), encoding='utf-8')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
