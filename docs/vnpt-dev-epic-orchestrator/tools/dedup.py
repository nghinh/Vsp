#!/usr/bin/env python3
"""
dedup.py — shared duplicate-detection gate for the VNPT dev-story and dev-epic
orchestrators. The canonical copy in the bundle lives next to this
script (one per orchestrator: docs/vnpt-dev-{epic,story}-orchestrator/tools/dedup.py
in a consumer repo). The script is path-independent — it detects the
repo root via `git rev-parse --show-toplevel` — so callers invoke it
as a cwd-relative path with no env var required.

Implements the 6-gate flow described in the orchestrator spec:

  Cy   (exact name match — Serena primary, `npx gitnexus context` fallback)
  CC   (symbol same-name? -> signature check)
  Emb  (embeddings enabled? -> semantic query)
  AI   (LLM judge reads top-3 + source, decides REUSE/EXTRACT/CONFLICT)
  Pre  (final pre-write recheck on the proposed symbol)
  Done (`npx gitnexus analyze --embeddings` to refresh the graph)

Gate Cy was upgraded from gitnexus-only to a Serena-primary path so the
exact-name check matches the design diagram (Cy = "Serena: exact name
match"). When Serena is not importable (host Python < 3.11, missing
language servers, no Go toolchain, etc.) the script transparently
falls back to `npx gitnexus context` and tags the response with
`_backend: "gitnexus_fallback"` plus a `fallback_reason` for forensics.

Serena install: `uv tool install -p 3.13 serena-agent` (or set
SERENA_AUTO_INSTALL=1 in the environment for one-shot auto-install).
See `_serena_available` and `_ensure_serena` for the resolution order.

The script is intentionally a thin CLI shell so it stays synchronous,
deterministic, and easy to invoke from a subagent `bash` tool. It
returns JSON on stdout for the LLM to interpret.

Usage:
  dedup.py exact <symbol-name> [--file <path>]
  dedup.py similar <symbol-name> [--intent "<text>"] [--top 3]
  dedup.py precheck <symbol-name> [--file <path>]
  dedup.py reindex [--embeddings]
  dedup.py loop-once <symbol-name> [--file <path>] [--intent "<text>"]

The `loop-once` command is the canonical entry used by the implementer
subagent after a Write tool returns success. It runs the full chain and
emits a JSON decision block the LLM reads to drive REUSE / EXTRACT /
CONFLICT / CONTINUE.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import subprocess
import sys
import importlib
from pathlib import Path
from typing import Any

def _detect_repo_root() -> Path:
    """Detect repo root via `git rev-parse --show-toplevel`, fallback to cwd.

    This is depth-independent: works whether the script lives at
    `<repo>/scripts/`, `<repo>/tools/x/y/`, or anywhere else inside a
    git working tree. Falls back to os.getcwd() if not in a git repo
    (e.g. running from a copy of the script outside any repo).
    """
    try:
        completed = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=10,
        )
        if completed.returncode == 0 and completed.stdout.strip():
            return Path(completed.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return Path.cwd()


REPO_ROOT = _detect_repo_root()
NPM_GITNEXUS = "npx"
GITNEXUS = "gitnexus"
REPO_NAME = "vnpt-ai-driven-platform"


def run(cmd: list[str], timeout: int = 60) -> dict[str, Any]:
    """Run a CLI command, return parsed JSON or raw text under `text` key."""
    try:
        completed = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, cwd=REPO_ROOT
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"timeout after {timeout}s: {' '.join(cmd)}"}
    if completed.returncode != 0:
        return {
            "ok": False,
            "returncode": completed.returncode,
            "stderr": completed.stderr.strip()[:500],
            "stdout": completed.stdout.strip()[:500],
            "cmd": cmd,
        }
    out = completed.stdout.strip()
    try:
        return {"ok": True, "data": json.loads(out)}
    except json.JSONDecodeError:
        return {"ok": True, "data": None, "text": out}


def gitnexus_indexed() -> bool:
    """Quick check: is GitNexus index present and readable?"""
    res = run([NPM_GITNEXUS, GITNEXUS, "status"], timeout=15)
    if not res["ok"]:
        return False
    text = (res.get("text") or "").lower()
    return "up-to-date" in text or "stale" in text


def gitnexus_embeddings_enabled() -> bool:
    """Heuristic: probe a small query; if the timing block reports a
    non-zero vector-phase elapsed time, embeddings are on.

    Note: `loop_once` no longer calls this function. It reads the
    `vector` timing field from the same response that carries the
    semantic-query results, saving one subprocess call per slice.
    This standalone helper is kept for pre-flight checks and external
    callers that need a dedicated embeddings probe.
    """
    res = run(
        [NPM_GITNEXUS, GITNEXUS, "query", "duplicate probe",
         "--repo", REPO_NAME, "--limit", "1"],
        timeout=30,
    )
    if not res["ok"]:
        return False
    data = res.get("data") or {}
    timing = data.get("timing") if isinstance(data, dict) else None
    if not timing:
        return False
    return bool(timing.get("vector", 0) > 0)



# --- Serena integration (gate Cy: exact name match) ---------------------
# Lazy-installed via `uvx --from serena-agent` on first use. Falls back to
# `npx gitnexus context` if Serena is not importable so the gate never
# becomes a hard dependency of the loop. The first call to
# `_ensure_serena()` may take a few seconds while uvx resolves the package.
_SERENA_AGENT_CACHE: dict[str, Any] = {}


_SERENA_SITE_PACKAGES_CANDIDATES = (
    # `uv tool install -p 3.13 serena-agent` (primary install path)
    "~/.local/share/uv/tools/serena-agent/lib/python3.13/site-packages",
    # Fallback: any python3.X site-packages under the tool venv
    "~/.local/share/uv/tools/serena-agent/lib",
    # `pipx install serena-agent`
    "~/.local/pipx/venvs/serena-agent/lib/python3.13/site-packages",
    "~/.local/pipx/venvs/serena-agent/lib",
    # System-level fallback (Debian/Ubuntu may package it differently)
    "/usr/lib/python3/dist-packages",
)


def _serena_site_packages() -> str | None:
    """Locate the directory that contains `serena/__init__.py`.

    Returns the path or None. We probe the documented install layouts
    rather than scanning the whole filesystem. This keeps the cost
    bounded to ~6 stat() calls.
    """
    import os
    for raw in _SERENA_SITE_PACKAGES_CANDIDATES:
        expanded = os.path.expanduser(raw)
        if not os.path.isdir(expanded):
            continue
        # If the candidate is the tool root (`lib`), drill into the
        # first python3.X site-packages we find.
        if not expanded.endswith("site-packages"):
            try:
                children = sorted(os.listdir(expanded))
            except OSError:
                continue
            for c in children:
                if c.startswith("python3.") and c.endswith("-lib") is False:
                    sub = os.path.join(expanded, c, "site-packages")
                    if os.path.isfile(os.path.join(sub, "serena", "__init__.py")):
                        return sub
            continue
        if os.path.isfile(os.path.join(expanded, "serena", "__init__.py")):
            return expanded
    return None


def _serena_available() -> bool:
    """Return True if `serena` Python module is importable.

    Order of resolution:
      1. Direct `import serena` (host Python already on sys.path).
      2. Auto-insert the serena-agent venv site-packages from one of
         the documented install layouts.
      3. Probe `uv tool run --from serena-agent` (cheap, uses cache).
    Does NOT install anything. Returns False on any failure so the
    caller can decide whether to fall back.
    """
    try:
        importlib.import_module("serena")
        return True
    except Exception:
        pass
    site = _serena_site_packages()
    if site and site not in sys.path:
        sys.path.insert(0, site)
        try:
            importlib.import_module("serena")
            return True
        except Exception:
            pass
    # Last resort: a one-shot `uv tool run` probe. This is a no-op when
    # serena-agent is already installed; the cost is one cached venv
    # resolution (~100ms). We do NOT call `uvx --from` because that
    # creates an ephemeral venv that is not importable from the host.
    from shutil import which
    if which("uv") is not None:
        probe = run(
            ["uv", "tool", "run", "--from", "serena-agent",
             "python", "-c", "import serena"],
            timeout=30,
        )
        if probe["ok"]:
            return True
    return False


def _ensure_serena() -> dict[str, Any]:
    """Lazy-activate Serena for exact name match (gate Cy).

    On first call:
      1. Probe importability via `_serena_available` (cheap).
         If not importable, attempt one install via
         `uv tool install -p 3.13 serena-agent`. We do NOT install by
         default; the orchestrator can preinstall or set
         `SERENA_AUTO_INSTALL=1` to opt in.
      2. Insert the serena-agent venv site-packages into sys.path if
         needed, then `import serena`.
      3. Instantiate `SerenaAgent(project=REPO_ROOT)` and activate the
         project.
      4. Cache the agent in `_SERENA_AGENT_CACHE` so subsequent calls
         skip install + activation.

    Returns:
      {"ok": True, "agent": SerenaAgent} on success.
      {"ok": False, "reason": "<short>"} on any failure. The caller
      decides whether to fall back to gitnexus.
    """
    if "agent" in _SERENA_AGENT_CACHE:
        return {"ok": True, "agent": _SERENA_AGENT_CACHE["agent"]}
    if "error" in _SERENA_AGENT_CACHE:
        return {"ok": False, "reason": _SERENA_AGENT_CACHE["error"]}

    # Opt-in auto-install. Off by default so we never mutate the host
    # environment without the orchestrator's consent.
    import os
    auto_install = os.environ.get("SERENA_AUTO_INSTALL", "0") == "1"

    if not _serena_available():
        if auto_install:
            from shutil import which
            if which("uv") is None:
                _SERENA_AGENT_CACHE["error"] = "uv not on PATH and auto-install requested"
                return {"ok": False, "reason": _SERENA_AGENT_CACHE["error"]}
            install = run(
                ["uv", "tool", "install", "-p", "3.13", "serena-agent"],
                timeout=240,
            )
            if not install["ok"]:
                _SERENA_AGENT_CACHE["error"] = f"uv tool install serena-agent failed: {install.get('stderr', install.get('error', 'unknown'))[:200]}"
                return {"ok": False, "reason": _SERENA_AGENT_CACHE["error"]}
            # Re-probe after install.
            if not _serena_available():
                _SERENA_AGENT_CACHE["error"] = "serena still not importable after install"
                return {"ok": False, "reason": _SERENA_AGENT_CACHE["error"]}
        else:
            _SERENA_AGENT_CACHE["error"] = "serena module not importable; set SERENA_AUTO_INSTALL=1 to auto-install"
            return {"ok": False, "reason": _SERENA_AGENT_CACHE["error"]}

    # Import + activate.
    try:
        from serena.agent import SerenaAgent  # type: ignore
        agent = SerenaAgent(project=str(REPO_ROOT))
        agent.activate_project()
        _SERENA_AGENT_CACHE["agent"] = agent
        return {"ok": True, "agent": agent}
    except Exception as e:  # broad: any import/config failure => fallback
        msg = f"{type(e).__name__}: {e}"[:200]
        _SERENA_AGENT_CACHE["error"] = msg
        return {"ok": False, "reason": msg}


def _serena_find_symbol(name: str, substring: bool = False) -> dict[str, Any]:
    """Call Serena's FindSymbolTool and normalize the result.

    Returns:
      {"ok": True, "matches": [...], "match_count": int} on success.
      {"ok": False, "reason": str} on any error.
    """
    ensured = _ensure_serena()
    if not ensured["ok"]:
        return {"ok": False, "reason": ensured["reason"]}
    agent = ensured["agent"]
    try:
        from serena.tools.symbol_tools import FindSymbolTool  # type: ignore
        tool = FindSymbolTool(agent)
        raw_json = tool.apply(
            name_path_pattern=name,
            substring_matching=substring,
            max_matches=50,
        )
        # FindSymbolTool returns a JSON string of grouped symbol dicts.
        try:
            parsed = json.loads(raw_json) if isinstance(raw_json, str) else raw_json
        except json.JSONDecodeError:
            parsed = raw_json
        # Normalize: FindSymbolTool returns a dict (post-grouping) with
        # a top-level list. Coerce defensively.
        matches: list[Any] = []
        if isinstance(parsed, list):
            matches = parsed
        elif isinstance(parsed, dict):
            for key in ("symbols", "matches", "results"):
                if key in parsed and isinstance(parsed[key], list):
                    matches = parsed[key]
                    break
            else:
                # Grouped dict-of-lists form: collect all list values.
                for v in parsed.values():
                    if isinstance(v, list):
                        matches.extend(v)
        return {"ok": True, "matches": matches, "match_count": len(matches)}
    except Exception as e:
        return {"ok": False, "reason": f"{type(e).__name__}: {e}"[:200]}


def _serena_candidates_to_gitnexus_shape(name: str, matches: list[Any]) -> list[dict[str, Any]]:
    """Map Serena match dicts -> GitNexus candidate dicts.

    The downstream code in `loop_once` and `signature_compat` expects
    fields like `filePath`, `kind`, `namePath`. Serena's grouped result
    uses `relative_path` and `kind_path` (per its to_dict config).
    We coerce field-by-field and silently drop matches missing both.
    """
    out: list[dict[str, Any]] = []
    for m in matches:
        if not isinstance(m, dict):
            continue
        file_path = (
            m.get("relative_path")
            or m.get("filePath")
            or m.get("file_path")
            or ""
        )
        kind = (
            m.get("kind")
            or (m.get("kind_path") or [None])[0]
            or ""
        )
        name_path = (
            m.get("name_path")
            or m.get("namePath")
            or name
        )
        if not file_path and not name_path:
            continue
        out.append({
            "filePath": file_path,
            "kind": str(kind),
            "namePath": str(name_path),
            "_source": "serena",
        })
    return out


def exact_match(name: str) -> dict[str, Any]:
    """Gate Cy: exact-name match via Serena (primary) or gitnexus (fallback).

    Primary path: `_serena_find_symbol` -> `_serena_candidates_to_gitnexus_shape`.
    Fallback path (Serena unavailable / errored): `npx gitnexus context <name>`.
    The output shape is identical regardless of source so downstream
    gates (CC, SigCheck) do not need to know which backend answered.
    A `_backend` field is added for forensics.
    """
    serena_res = _serena_find_symbol(name, substring=False)
    if serena_res["ok"]:
        cands = _serena_candidates_to_gitnexus_shape(name, serena_res["matches"])
        if cands:
            return {
                "gate": "Cy",
                "name": name,
                "matched": True,
                "candidates": cands,
                "_backend": "serena",
                "match_count": serena_res["match_count"],
            }
        # Serena ran clean and found nothing -> exact name does not exist.
        return {
            "gate": "Cy",
            "name": name,
            "matched": False,
            "candidates": [],
            "_backend": "serena",
            "match_count": 0,
        }

    # Fallback: gitnexus context (existing behaviour, preserved verbatim).
    res = run(
        [NPM_GITNEXUS, GITNEXUS, "context", name, "--repo", REPO_NAME],
        timeout=30,
    )
    if not res["ok"]:
        return {
            "gate": "Cy",
            "name": name,
            "matched": False,
            "reason": f"serena: {serena_res['reason']}; gitnexus: {res.get('error', 'context query failed')}",
            "_backend": "gitnexus_fallback",
        }
    data = res.get("data") or {}
    status = data.get("status", "")
    matched = status in ("found", "ambiguous")
    return {
        "gate": "Cy",
        "name": name,
        "matched": matched,
        "status": status,
        "candidates": data.get("candidates", []),
        "_backend": "gitnexus_fallback",
        "fallback_reason": serena_res["reason"],
    }


def _extract_kind_from_path(file_path: str) -> str:
    """Best-effort inference of a symbol kind from its file path.

    Used by signature_compat as one of the cheap structural signals.
    Returns "internal" for vendored Go paths, "cmd" for CLI entrypoints,
    "test" for test files, "external" otherwise.
    """
    if not file_path:
        return "unknown"
    fp = file_path.lower()
    if "/cmd/" in fp or fp.endswith("/main.go"):
        return "cmd"
    if "_test.go" in fp or "/tests/" in fp:
        return "test"
    if "/internal/" in fp:
        return "internal"
    if "/external/" in fp or "/vendor/" in fp:
        return "external"
    return "other"


def signature_compat(candidate: dict[str, Any], new_signature_hint: str | None) -> dict[str, Any]:
    """Gate SigCheck: structural signature compatibility check.

    Returns one of three verdicts:
      - "yes"   — candidate is in the same scope as the new proposal
                   and has the same kind; likely safe to REUSE.
      - "no"    — candidate is in a different scope (cmd vs internal vs
                   external) or has a different kind; CONFLICT likely.
      - "review" — signals are ambiguous (missing hint, missing candidate
                   fields, or no comparable structure). The LLM judge
                   must read source and decide.

    This is intentionally a coarse pre-filter. The LLM judge still has
    the final say via `next_action_hint`.
    """
    if not new_signature_hint:
        return {
            "compatible": "review",
            "reason": "no new signature hint supplied; LLM judge required",
        }

    cand_file = candidate.get("filePath", "")
    cand_kind = (candidate.get("kind") or "").lower()
    cand_scope = _extract_kind_from_path(cand_file)

    # Compare candidate scope to the NEW PROPOSAL's scope (derived from
    # the hint). Match -> likely a safe REUSE. Mismatch -> CONFLICT
    # (caller must rename or namespace).
    #
    # The `kind` field is captured for context but is NOT used to gate
    # the verdict because real GitNexus output often has `kind: ""`
    # (e.g. for symbols defined inside multi-package command files).
    # Falling back to "review" on empty kind would make this gate a
    # no-op for those candidates. Scope is the cheaper and more
    # reliable signal.
    hint_scope = _extract_kind_from_path(new_signature_hint)
    same_scope = (
        hint_scope != "unknown"
        and cand_scope != "unknown"
        and hint_scope == cand_scope
    )
    if same_scope:
        verdict = "yes"
        verdict_reason = (
            f"candidate scope={cand_scope} matches proposal scope={hint_scope}; "
            f"safe to REUSE the existing symbol"
        )
    elif hint_scope != "unknown" and cand_scope != "unknown":
        verdict = "no"
        verdict_reason = (
            f"candidate scope={cand_scope} differs from proposal scope={hint_scope}; "
            f"CONFLICT — rename the new symbol or namespace it"
        )
    else:
        verdict = "review"
        verdict_reason = (
            f"cannot determine scope match: candidate_scope={cand_scope} "
            f"hint_scope={hint_scope}; LLM judge required"
        )
    return {
        "compatible": verdict,
        "reason": verdict_reason,
        "candidate_file": cand_file,
        "candidate_scope": cand_scope,
        "candidate_kind": cand_kind,
        "proposal_scope": hint_scope,
        "hint": new_signature_hint,
    }


def semantic_query(intent: str, top: int) -> dict[str, Any]:
    """Gate Emb/Q: vector + BM25 query, returns top-N process_symbols."""
    res = run(
        [NPM_GITNEXUS, GITNEXUS, "query", intent,
         "--repo", REPO_NAME, "--limit", str(top)],
        timeout=45,
    )
    if not res["ok"]:
        return {"ok": False, "error": res.get("error", "query failed")}
    data = res.get("data") or {}
    return {
        "ok": True,
        "processes": data.get("processes", []),
        "process_symbols": data.get("process_symbols", []),
        "definitions": data.get("definitions", []),
        "timing": data.get("timing", {}),
    }


def pre_write_check(symbol_name: str, file_hint: str | None) -> dict[str, Any]:
    """Gate Pre: final pre-write recheck. Combines exact-name + scope sanity."""
    exact = exact_match(symbol_name)
    return {
        "gate": "Pre",
        "name": symbol_name,
        "exact_match": exact.get("matched", False),
        "file_hint": file_hint,
        "new_duplicate_likely": bool(exact.get("matched")),
    }


def reindex(embeddings: bool = False) -> dict[str, Any]:
    """Gate Done: refresh the GitNexus graph. Embeddings off by default to
    keep the loop fast; turn on with --embeddings for the final pass.

    The function default matches the CLI default (no embeddings). The
    final post-slice reindex should pass `embeddings=True` to keep the
    graph semantically rich for the next slice.

    Returns a dict with `ok`, plus on failure: `stderr`, `returncode`,
    and the `cmd` list (truncated for safety). On success with
    embeddings disabled, a `warnings` field hints that semantic search
    may be stale.
    """
    cmd = [NPM_GITNEXUS, GITNEXUS, "analyze"]
    if embeddings:
        cmd.append("--embeddings")
    res = run(cmd, timeout=300)
    out: dict[str, Any] = {
        "gate": "Done",
        "ok": res["ok"],
        "embeddings": bool(embeddings),
    }
    if not res["ok"]:
        out["stderr"] = res.get("stderr", "")[:500]
        out["returncode"] = res.get("returncode")
        out["cmd"] = res.get("cmd", cmd)[:8]  # truncate for safety
    elif not embeddings:
        out["warnings"] = [
            "embeddings not refreshed; semantic search may be stale for the next slice",
        ]
    return out


def run_gate_chain(name: str, file_hint: str | None, intent: str, top: int) -> dict[str, Any]:
    """Run the 6-gate flow once and return a decision dict.

    This is the composable core (no argparse dependency). `loop_once`
    and `report` both build on it. The dict always carries a `decision`
    field the caller dispatches on; the script never edits source code.
    """
    if not gitnexus_indexed():
        return {
            "decision": "ABORT",
            "reason": "gitnexus index missing or unreadable; run `npx gitnexus analyze` first",
        }

    # Cy
    exact = exact_match(name)
    if exact.get("matched"):
        candidates = exact.get("candidates", [])
        top_cand = candidates[0] if candidates else {}
        sig = signature_compat(top_cand, file_hint)
        return {
            "decision": "REVIEW",
            "gate_chain": ["Cy", "CC", "SigCheck"],
            "exact_match": True,
            "candidates": candidates,
            "signature": sig,
            "next_action_hint": (
                "If signature matches -> REUSE the existing symbol. "
                "If signature differs -> CONFLICT (rename or namespace)."
            ),
        }

    # Q + AI judge input. Coerce each result list defensively in case
    # gitnexus returns a non-list type (Fix E).
    #
    # Optimization (Fix O1): we previously called
    # `gitnexus_embeddings_enabled()` first (a "duplicate probe" query
    # whose results were thrown away), then the real intent query
    # separately. That cost one extra subprocess call (~600ms) per
    # loop-once. The single intent query returns a `timing` block whose
    # `vector` field already tells us whether embeddings are on, so we
    # read embeddings from the same response.
    semantic = semantic_query(intent, top)
    timing = semantic.get("timing") or {}
    embeddings_enabled = bool(timing.get("vector", 0) > 0)

    # Emb gate: when embeddings are off, semantic search is meaningless;
    # return PRE_WRITE without slicing results.
    if not embeddings_enabled:
        return {
            "decision": "PRE_WRITE",
            "gate_chain": ["Cy", "Emb(no)"],
            "embeddings_enabled": False,
            "next_action_hint": (
                "No embeddings — skip semantic search. "
                "Run pre_write_check, then write, then reindex."
            ),
        }

    raw_symbols = semantic.get("process_symbols") or []
    raw_defs = semantic.get("definitions") or []
    if not isinstance(raw_symbols, list):
        raw_symbols = []
    if not isinstance(raw_defs, list):
        raw_defs = []
    top_n = max(0, int(top))
    sym_sliced = raw_symbols[:top_n]
    def_sliced = raw_defs[:top_n]
    truncated_symbols = len(raw_symbols) > len(sym_sliced)
    truncated_defs = len(raw_defs) > len(def_sliced)

    # Fix H: handle three empty-result cases distinctly.
    #   - top_n == 0   -> SKIP_SEMANTIC (user opted out of semantic search)
    #   - top_n > 0 and no results -> NO_SEMANTIC_MATCH (gate ran, found nothing)
    if top_n == 0:
        return {
            "decision": "SKIP_SEMANTIC",
            "gate_chain": ["Cy", "Emb", "Q"],
            "embeddings_enabled": True,
            "semantic_top": [],
            "semantic_definitions": [],
            "next_action_hint": (
                "Semantic search was skipped (--top 0). Proceed to "
                "pre_write_check; if that is clean, the new symbol is "
                "safe to write."
            ),
        }
    if not sym_sliced and not def_sliced:
        return {
            "decision": "NO_SEMANTIC_MATCH",
            "gate_chain": ["Cy", "Emb", "Q"],
            "embeddings_enabled": True,
            "semantic_top": [],
            "semantic_definitions": [],
            "next_action_hint": (
                "Semantic query returned no results. The intent did not "
                "match any indexed symbol semantically. Proceed to "
                "pre_write_check; if that is clean, the new symbol is "
                "safe to write."
            ),
        }

    return {
        "decision": "AI_JUDGE",
        "gate_chain": ["Cy", "Emb", "Q"],
        "embeddings_enabled": True,
        "semantic_top": sym_sliced,
        "semantic_definitions": def_sliced,
        "truncated": truncated_symbols or truncated_defs,
        "available_symbol_count": len(raw_symbols),
        "available_def_count": len(raw_defs),
        "requested_top": top_n,
        "next_action_hint": (
            "LLM: read each top result's source + the new proposal. "
            "Decide REUSE / EXTRACT / CONFLICT. "
            "On REUSE: replace the proposal with the existing symbol call. "
            "On EXTRACT: create a shared util and refactor both sites. "
            "On CONFLICT: rename the new symbol and re-run from Cy."
        ),
    }


def loop_once(args: argparse.Namespace) -> dict[str, Any]:
    """Run the 6-gate flow once. The LLM reads this JSON and decides
    REUSE / EXTRACT / CONFLICT / CONTINUE; stdout-only (no file write).
    """
    return run_gate_chain(args.symbol, args.file, args.intent or args.symbol, args.top)


# --- dedup_report.json layer -------------------------------------------------
# Decision buckets the report writer derives status from.
_CLEAN_DECISIONS = frozenset({"PRE_WRITE", "SKIP_SEMANTIC", "NO_SEMANTIC_MATCH"})
_BLOCK_DECISIONS = frozenset({"REVIEW", "AI_JUDGE"})
_REPORT_SCHEMA_VERSION = "1.0.0"


def recommend_refactor_action(decision: str, signature: dict[str, Any] | None) -> str:
    """Derive the script's recommended refactor action for a decision.

    This is a hint for the agent-driven auto-refactor loop; the LLM makes
    the final call (e.g. it may choose NAMESPACE over RENAME, or judge
    intent before EXTRACT). Returns one of REUSE/RENAME/EXTRACT/NONE.
    """
    if decision == "REVIEW":
        compat = (signature or {}).get("compatible")
        if compat == "yes":
            return "REUSE"
        if compat == "no":
            return "RENAME"
        return "NONE"  # ambiguous scope -> LLM must judge
    if decision == "AI_JUDGE":
        return "EXTRACT"  # default; agent confirms against intent
    return "NONE"


def derive_block_reason(decision: str, signature: dict[str, Any] | None) -> str | None:
    """Human-readable reason when a decision blocks the write."""
    if decision == "REVIEW":
        compat = (signature or {}).get("compatible")
        if compat == "yes":
            return "exact-name collision with a signature-compatible symbol; REUSE candidate exists"
        if compat == "no":
            return "exact-name collision with a signature-incompatible symbol; CONFLICT (rename/namespace)"
        return "exact-name collision; scope ambiguous, LLM must judge reuse vs conflict"
    if decision == "AI_JUDGE":
        return "semantic duplicate detected; LLM must judge REUSE/EXTRACT/RENAME against intent"
    return None


def compute_report_status(attempts: list[dict[str, Any]]) -> str:
    """Roll up attempt history into a terminal status.

    - clean   : latest attempt is proceed-eligible and no earlier block
    - resolved: latest attempt is proceed-eligible but an earlier block was fixed
    - blocked : latest attempt is a BLOCK (REVIEW/AI_JUDGE)
    - failed  : latest attempt aborted (index missing etc.)
    """
    if not attempts:
        return "failed"
    latest = attempts[-1].get("decision")
    if latest == "ABORT":
        return "failed"
    had_block = any(a.get("decision") in _BLOCK_DECISIONS for a in attempts)
    if latest in _BLOCK_DECISIONS:
        return "blocked"
    return "resolved" if had_block else "clean"


def _now_iso() -> str:
    """UTC timestamp in RFC3339. (Plain Python CLI; datetime is allowed.)"""
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _read_report_container(path: Path) -> dict[str, Any]:
    """Load an existing dedup_report.json container, or return a fresh one.

    A container holds one report object per (slice_id, symbol).
    """
    if path.is_file():
        try:
            data = json.loads(path.read_text())
            if isinstance(data, dict) and "reports" in data:
                return data
        except (json.JSONDecodeError, OSError):
            pass  # corrupt/missing -> start fresh
    return {"schema_version": _REPORT_SCHEMA_VERSION, "story_id": None, "reports": []}


def _write_report_container_atomic(path: Path, data: dict[str, Any]) -> bool:
    """Atomic write via .tmp + os.replace (same filesystem -> atomic).

    Returns True on success, False on IO failure. Never raises so the
    caller can still emit the run JSON to stdout.
    """
    tmp = path.with_name(path.name + ".tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp.write_text(json.dumps(data, indent=2))
        os.replace(tmp, path)
        return True
    except OSError as e:
        # Best-effort cleanup of the temp file; ignore failures.
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass
        print(f"warning: failed to write {path}: {type(e).__name__}: {e}", file=sys.stderr)
        return False


def report_cmd(args: argparse.Namespace) -> dict[str, Any]:
    """Run one gate-chain pass and persist it as an attempt in
    dedup_report.json. The file is the durable audit trail the
    agent-driven auto-refactor loop appends to on every iteration.
    """
    run = run_gate_chain(args.symbol, args.file, args.intent or args.symbol, args.top)
    decision = run.get("decision", "ABORT")

    attempt: dict[str, Any] = {
        "attempt": 0,  # filled after we know the slice/symbol index
        "timestamp": _now_iso(),
        "phase": args.phase,
        "decision": decision,
        "gate_chain": run.get("gate_chain", []),
        "gates": [],  # reserved for raw per-gate dicts; populated by callers if needed
        "candidates": run.get("candidates", []),
        "signature": run.get("signature"),
        "refactor_action": recommend_refactor_action(decision, run.get("signature")),
        "refactor_applied": bool(args.refactor_applied),
        "block_reason": derive_block_reason(decision, run.get("signature")),
    }
    # Surface semantic hits on AI_JUDGE attempts so the report is self-contained.
    if decision == "AI_JUDGE":
        attempt["semantic_top"] = run.get("semantic_top", [])
        attempt["semantic_definitions"] = run.get("semantic_definitions", [])

    path = Path(args.out_dir) / "dedup_report.json"
    container = _read_report_container(path)
    container["story_id"] = args.story_id or container.get("story_id")

    reports = container.setdefault("reports", [])
    # Find the report for this (slice_id, symbol); create if absent.
    report = next(
        (r for r in reports
         if r.get("slice_id") == args.slice_id and r.get("symbol") == args.symbol),
        None,
    )
    if report is None:
        report = {
            "slice_id": args.slice_id,
            "symbol": args.symbol,
            "file": args.file,
            "final_decision": decision,
            "status": "blocked" if decision in _BLOCK_DECISIONS else "clean",
            "block_reason": None,
            "refactor_action_applied": "NONE",
            "max_attempts": int(args.max_attempts),
            "attempts": [],
        }
        reports.append(report)

    attempt["attempt"] = len(report["attempts"]) + 1
    report["attempts"].append(attempt)

    # Recompute terminal fields from the full attempt history.
    report["final_decision"] = decision
    report["status"] = compute_report_status(report["attempts"])
    report["block_reason"] = derive_block_reason(decision, run.get("signature"))
    # The most recently applied action wins; otherwise show the recommendation.
    applied = next(
        (a["refactor_action"] for a in reversed(report["attempts"]) if a.get("refactor_applied")),
        None,
    )
    report["refactor_action_applied"] = applied or attempt["refactor_action"]

    # Escalation signal: the agent-driven auto-refactor loop exhausted its
    # attempt budget while still blocked. Flip the terminal fields so the
    # orchestrator/runner can detect BLOCKED_MAX_ATTEMPTS deterministically
    # (matches the escalation contract in the implementer prompts).
    max_attempts = int(args.max_attempts)
    report["max_attempts"] = max_attempts
    still_blocked = decision in _BLOCK_DECISIONS and len(report["attempts"]) >= max_attempts
    if still_blocked:
        report["final_decision"] = "BLOCKED_MAX_ATTEMPTS"
        report["status"] = "blocked"
        report["block_reason"] = (
            f"auto-refactor loop exhausted {max_attempts} attempts; last gate={decision}: "
            f"{derive_block_reason(decision, run.get('signature'))}"
        )

    written_ok = _write_report_container_atomic(path, container)

    # Always echo the single-run JSON for the LLM to act on immediately.
    run["_report_path"] = str(path) if written_ok else None
    run["_report_status"] = report["status"]
    run["_report_attempt"] = attempt["attempt"]
    run["_block"] = decision in _BLOCK_DECISIONS
    run["_exhausted"] = still_blocked
    if decision in _BLOCK_DECISIONS:
        run["_refactor_action_recommended"] = attempt["refactor_action"]
    return run


def main() -> int:
    parser = argparse.ArgumentParser(description="VNPT shared duplicate detection (dev-story + dev-epic orchestrators)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_exact = sub.add_parser("exact", help="Gate Cy: exact-name match")
    p_exact.add_argument("name")
    p_exact.add_argument("--file", default=None)

    p_sim = sub.add_parser("similar", help="Gate Emb/Q: semantic query")
    p_sim.add_argument("name")
    p_sim.add_argument("--intent", default=None)
    p_sim.add_argument("--top", type=int, default=3)

    p_pre = sub.add_parser("precheck", help="Gate Pre: pre-write recheck")
    p_pre.add_argument("name")
    p_pre.add_argument("--file", default=None)

    p_ri = sub.add_parser(
        "reindex",
        help="Gate Done: refresh graph (embeddings OFF by default; pass --embeddings for the final pass)",
    )
    p_ri.add_argument(
        "--embeddings",
        action="store_true",
        help="Regenerate vector embeddings during reindex. Off by default to keep the loop fast.",
    )

    p_loop = sub.add_parser(
        "loop-once",
        help="Run the 6-gate flow once after a Write tool success. Returns JSON decision block.",
    )
    p_loop.add_argument("symbol")
    p_loop.add_argument("--file", default=None)
    p_loop.add_argument("--intent", default=None)
    p_loop.add_argument("--top", type=int, default=3)

    p_rep = sub.add_parser(
        "report",
        help="Run one gate-chain pass and append it as an attempt to <out-dir>/dedup_report.json.",
    )
    p_rep.add_argument("symbol")
    p_rep.add_argument("--file", default=None)
    p_rep.add_argument("--intent", default=None)
    p_rep.add_argument("--top", type=int, default=3)
    p_rep.add_argument("--story-id", default=None, help="Story identifier (e.g. S-007)")
    p_rep.add_argument("--slice-id", default=None, help="Slice identifier within the story")
    p_rep.add_argument(
        "--out-dir", default=None,
        help="Directory for dedup_report.json (omit for stdout-only loop-once behaviour)",
    )
    p_rep.add_argument("--phase", choices=["pre", "post"], default="post", help="pre- or post-write gate")
    p_rep.add_argument("--max-attempts", type=int, default=3, help="Cap for the agent-driven auto-refactor loop")
    p_rep.add_argument(
        "--refactor-applied", action="store_true",
        help="Mark that the agent applied the recommended refactor before this pass",
    )

    args = parser.parse_args()

    if args.cmd == "exact":
        out = exact_match(args.name)
    elif args.cmd == "similar":
        out = semantic_query(args.intent or args.name, args.top)
    elif args.cmd == "precheck":
        out = pre_write_check(args.name, args.file)
    elif args.cmd == "reindex":
        out = reindex(embeddings=args.embeddings)
    elif args.cmd == "loop-once":
        out = loop_once(args)
    elif args.cmd == "report":
        out = report_cmd(args)
    else:
        parser.error(f"unknown command: {args.cmd}")
        return 2

    print(json.dumps(out, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
