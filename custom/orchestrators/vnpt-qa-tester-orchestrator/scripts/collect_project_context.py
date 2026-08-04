#!/usr/bin/env python3
"""Collect candidate context files for QA reading.

This script does not summarize files. It lists files an agent should read 0-EOF.
It is BMAD-aware and performs recursive discovery under docs/ because BMAD PRD,
architecture, epic, story, UX, API, and data files may be sharded into subfolders.
"""
from __future__ import annotations
import fnmatch
import json
import re
import sys
from pathlib import Path

INCLUDE_SUFFIXES = {'.md', '.mdx', '.txt', '.yaml', '.yml', '.json', '.toml', '.ts', '.tsx', '.js', '.jsx', '.py', '.java', '.cs', '.go', '.rs', '.sql'}
BMAD_DOC_SUFFIXES = {'.md', '.mdx', '.yaml', '.yml', '.json'}
EXCLUDE_DIRS = {'node_modules', '.git', 'dist', 'build', '.next', 'coverage', '.venv', 'venv', '__pycache__'}
# Generated QA artifacts under docs/qa are not source-of-truth BMAD inputs.
EXCLUDE_BMAD_PATTERNS = ['docs/qa/**', 'docs/**/.archive/**', 'docs/**/archive/**', 'docs/**/generated/**']
KEYWORDS = ['prd', 'requirement', 'requirements', 'story', 'stories', 'epic', 'architecture', 'arch', 'design', 'front-end', 'frontend', 'ux', 'ui', 'openapi', 'swagger', 'api', 'schema', 'database', 'migration', 'seed', 'acceptance', 'criteria', 'test', 'spec', 'readme']
BMAD_PRIORITY_PATTERNS = [
    # root-level conventional names
    'docs/prd.md', 'docs/PRD.md', 'docs/brownfield-prd.md', 'docs/project-brief.md', 'docs/brief.md',
    'docs/architecture.md', 'docs/fullstack-architecture.md', 'docs/front-end-spec.md', 'docs/frontend-spec.md', 'docs/ux-spec.md',
    'docs/epic*.md', 'docs/stor*.md',
    # recursive names at any depth under docs/
    'docs/**/prd*.md', 'docs/**/*prd*.md', 'docs/**/brownfield-prd*.md', 'docs/**/project-brief*.md', 'docs/**/brief*.md',
    'docs/**/architecture*.md', 'docs/**/*architecture*.md', 'docs/**/fullstack-architecture*.md',
    'docs/**/front-end-spec*.md', 'docs/**/frontend-spec*.md', 'docs/**/ux-spec*.md',
    'docs/**/epic*.md', 'docs/**/*epic*.md', 'docs/**/story*.md', 'docs/**/stories*.md', 'docs/**/*stor*.md',
    'docs/**/acceptance*.md', 'docs/**/*acceptance*.md',
    'docs/**/api*.md', 'docs/**/openapi*.yaml', 'docs/**/openapi*.yml',
    'docs/**/schema*.md', 'docs/**/data*.md',
    'docs/**/*.md', 'docs/**/*.mdx', 'docs/**/*.yaml', 'docs/**/*.yml', 'docs/**/*.json',
]


def match_any(rel: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel, pat) for pat in patterns)


def should_skip(path: Path) -> bool:
    return any(part in EXCLUDE_DIRS for part in path.parts)


def is_excluded_bmad(rel: str) -> bool:
    return match_any(rel, EXCLUDE_BMAD_PATTERNS)


def is_bmad_doc(rel: str, suffix: str) -> bool:
    return rel.startswith('docs/') and suffix.lower() in BMAD_DOC_SUFFIXES and not is_excluded_bmad(rel)


def read_headings(path: Path, max_lines: int = 120) -> str:
    try:
        lines = []
        with path.open('r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                if line.lstrip().startswith('#') or any(k in line.lower() for k in ('acceptance criteria', 'requirements', 'architecture', 'epic', 'story')):
                    lines.append(line.strip())
        return '\n'.join(lines).lower()
    except Exception:
        return ''


def bmad_type(rel: str, path: Path | None = None) -> str:
    s = rel.lower()
    headings = read_headings(path) if path else ''
    combined = f'{s}\n{headings}'
    if re.search(r'\bprd\b|product[-_ ]?requirement|requirements|project[-_ ]?brief|\bbrief\b|non[-_ ]?goals?|scope', combined):
        return 'PRD_OR_BRIEF'
    if 'architecture' in combined or 'system design' in combined or 'solution design' in combined or 'likec4' in combined or re.search(r'\bc4\b', combined):
        return 'ARCHITECTURE'
    if 'front-end' in combined or 'frontend' in combined or re.search(r'\bux\b|\bui\b|wireframe|screen|interaction', combined):
        return 'UX_FRONTEND_SPEC'
    if 'openapi' in combined or 'swagger' in combined or re.search(r'\bapi\b|endpoint|request|response|contract', combined):
        return 'API_SPEC'
    if 'schema' in combined or 'database' in combined or 'migration' in combined or 'seed' in combined or 'data model' in combined or 'erd' in combined:
        return 'DATA_MODEL'
    if 'epic' in combined:
        return 'EPIC'
    if 'stor' in combined or 'acceptance criteria' in combined:
        return 'STORY'
    return 'DOCS_MARKDOWN'


def score(path: Path, root: Path) -> int:
    rel = str(path.relative_to(root)).replace('\\', '/')
    s = rel.lower()
    val = 0
    if is_bmad_doc(rel, path.suffix):
        val += 100
    for pat in BMAD_PRIORITY_PATTERNS:
        if fnmatch.fnmatch(rel, pat):
            val += 50
            break
    for k in KEYWORDS:
        if k in s:
            val += 10
    # Add a small boost for detected BMAD headings in arbitrary nested docs.
    headings = read_headings(path)
    for k in KEYWORDS:
        if k in headings:
            val += 5
    if path.suffix.lower() in INCLUDE_SUFFIXES:
        val += 1
    return val


def line_count(path: Path) -> int | None:
    try:
        with path.open('rb') as f:
            return sum(1 for _ in f)
    except Exception:
        return None


def discovery_path(rel: str) -> str:
    if match_any(rel, BMAD_PRIORITY_PATTERNS):
        return 'recursive-docs-glob'
    if rel.startswith('docs/'):
        return 'recursive-docs-fallback'
    return 'project-context'


def collect(root: Path) -> dict:
    files = []
    bmad_docs = []
    docs_root = root / 'docs'
    recursive_docs_scan_done = docs_root.exists() and docs_root.is_dir()
    for p in root.rglob('*'):
        if p.is_file() and not should_skip(p) and p.suffix.lower() in INCLUDE_SUFFIXES:
            st = p.stat()
            if st.st_size <= 2_000_000:
                rel = str(p.relative_to(root)).replace('\\', '/')
                is_bmad = is_bmad_doc(rel, p.suffix)
                item = {
                    'path': rel,
                    'size': st.st_size,
                    'lines': line_count(p),
                    'score': score(p, root),
                    'bmad_type': bmad_type(rel, p) if is_bmad else None,
                    'discovery_path': discovery_path(rel),
                    'read_requirement': 'READ_0_EOF_REQUIRED_IF_SCOPE_RELEVANT' if is_bmad else 'READ_IF_SCOPE_RELEVANT',
                }
                files.append(item)
                if is_bmad:
                    bmad_docs.append(item)
    return {
        'bmad_docs_root': 'docs',
        'recursive_docs_scan_done': recursive_docs_scan_done,
        'bmad_docs_found': bool(bmad_docs),
        'bmad_docs_reading_contract': 'Recursively scan docs/** first; line-count and read relevant BMAD docs 0-EOF before risk modeling/test design. Do not assume PRD/architecture/epic/story files are direct children of docs/. Exclude generated docs/qa artifacts as source inputs.',
        'bmad_candidate_docs': sorted(bmad_docs, key=lambda x: (-x['score'], x['path']))[:300],
        'candidate_context_files': sorted(files, key=lambda x: (-x['score'], x['path']))[:400],
    }

if __name__ == '__main__':
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    data = {'root': str(root)}
    data.update(collect(root))
    print(json.dumps(data, ensure_ascii=False, indent=2))
