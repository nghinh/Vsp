#!/usr/bin/env python3
"""Run PICT if installed, otherwise create a deterministic fallback matrix.

Usage:
  python scripts/run_pict.py model.pict output.md
"""
from __future__ import annotations
import itertools
import shutil
import subprocess
import sys
from pathlib import Path


def parse_simple_model(text: str):
    params = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#') or line.upper().startswith('IF '):
            continue
        if ':' in line:
            name, values = line.split(':', 1)
            vals = [v.strip().strip('"') for v in values.split(',') if v.strip()]
            if vals:
                params.append((name.strip(), vals))
    return params


def fallback_matrix(params, limit=50):
    if not params:
        return []
    # Deterministic pairwise-inspired fallback: rotate values across max cardinality rows.
    max_len = max(len(v) for _, v in params)
    rows = []
    for i in range(min(max_len * max_len, limit)):
        row = {}
        for j, (name, vals) in enumerate(params):
            row[name] = vals[(i + j * (i + 1)) % len(vals)]
        rows.append(row)
    # Add first/last boundary rows
    rows.append({name: vals[0] for name, vals in params})
    rows.append({name: vals[-1] for name, vals in params})
    # Deduplicate
    seen = set(); out = []
    for r in rows:
        key = tuple(r.items())
        if key not in seen:
            seen.add(key); out.append(r)
    return out


def to_markdown(rows):
    if not rows:
        return '# Combinatorial Test Matrix\n\nNo rows generated.\n'
    headers = list(rows[0].keys())
    md = ['# Combinatorial Test Matrix', '', '| TC | ' + ' | '.join(headers) + ' |', '|---|' + '|'.join(['---'] * len(headers)) + '|']
    for i, row in enumerate(rows, 1):
        md.append('| QA-COMB-%03d | %s |' % (i, ' | '.join(str(row.get(h, '')) for h in headers)))
    return '\n'.join(md) + '\n'


def main():
    if len(sys.argv) < 3:
        print('Usage: run_pict.py model.pict output.md', file=sys.stderr)
        return 2
    model = Path(sys.argv[1])
    output = Path(sys.argv[2])
    pict = shutil.which('pict')
    if pict:
        proc = subprocess.run([pict, str(model)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode == 0:
            output.write_text(proc.stdout, encoding='utf-8')
            return 0
        print(proc.stderr, file=sys.stderr)
    params = parse_simple_model(model.read_text(encoding='utf-8'))
    output.write_text(to_markdown(fallback_matrix(params)), encoding='utf-8')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
