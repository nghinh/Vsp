"""Tests for scripts/validate_guardrails.py.

Covers the P0 strict-validation contract for
`config/medium-model-guardrails.yaml`:

- Required top-level fields and types
- Guardrail booleans must be present and typed
- response_style: required_sections + forbidden_behaviors non-empty
- traceability: known bool keys, no unknown keys
- test_id_prefixes: complete set of QA-* prefixes
- minimum_per_risk: P0 + P1 with non-negative int values
- medium_model_decomposition: known keys, typed
- minimax_m2_7_constraints: no unknown keys
- Non-empty list keys
- Placeholder detection: TODO, TBD, FIXME, XXX, lorem ipsum, {{var}},
  ${VAR}, [YOUR_*], CHANGEME, REPLACE_ME
- Code templates under automation_code_templates are exempt
- CLI behavior: missing file, YAML parse error, PASS, FAIL
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = PACKAGE_ROOT / "scripts"
VALIDATOR = SCRIPTS_DIR / "validate_guardrails.py"
REAL_CONFIG = PACKAGE_ROOT / "config" / "medium-model-guardrails.yaml"


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def run_validator(config_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VALIDATOR), str(config_path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


# ----------------------------------------------------------------------------
# Minimal valid v2.0.0 fixture used as the "good" baseline in negative tests.
# Tests mutate a deep-copy of this to assert specific failures.
# ----------------------------------------------------------------------------
MINIMAL_VALID = textwrap.dedent(
    """\
    orchestrator: vnpt-qa-tester-orchestrator
    profile: medium_model_strict
    version: 2.0.0

    phase_order_is_mandatory: true
    allow_phase_skip: false
    allow_automation_before_oracle: false
    allow_generic_placeholders_as_final: false
    allow_silent_assumptions: false
    allow_shallow_tests_to_count: false

    response_style:
      required_sections:
        - Inputs Read
        - Decisions
      forbidden_behaviors:
        - skip_phases_because_task_feels_simple

    traceability:
      require_test_id: true
      require_risk_id: true
      require_oracle_id: true
      require_requirement_id_when_available: true
      require_generated_from: true

    test_id_prefixes:
      QA-EX-: example-based
      QA-COMB-: combinatorial
      QA-SM-: state-machine
      QA-PROP-: property
      QA-API-: API schema/fuzz
      QA-E2E-: UI/E2E
      QA-REG-: regression
      QA-EXP-: exploratory/manual

    minimum_per_risk:
      P0:
        happy_path: 1
        negative_tests: 2
      P1:
        main_path_tests: 1

    required_bug_classes_to_consider:
      - wrong_state_transition

    labels_for_uncertainty:
      - SPEC_AMBIGUITY

    patterns_that_do_not_count:
      - only_checks_status_code_200

    what_counts_as_coverage:
      - domain_state_change

    self_review_required_before_final_report: true
    self_review_checklist:
      - Are negative and boundary cases present?

    require_phase_trace_table: true
    phase_trace_table_format: |
      | Input checked | Decision made | Output artifact | Open gap | Next action |

    medium_model_decomposition:
      enabled: true
      table_per_phase: true
      purpose: Reduce drift and make skipped steps obvious
      max_gap_unresolved: 3

    minimax_m2_7_constraints:
      no_visual_evidence: true
      forbidden_evidence_types:
        - screenshots
      required_evidence_types:
        - command_stdout_stderr
      visual_fallback_label: TOOL_GAP
      visual_fallback_required: true
      explicit_commands_required: true
      command_templates:
        python:
          test: "pytest -v 2>&1"
      phase_decision_tree: {}
      automation_code_templates:
        jest_typescript: |
          describe('<FeatureName>', () => {
            it('should <expected behavior>', () => {});
          });
      gate_report_json_schema:
        path: "docs/qa/x/10-quality-gate-report.json"
        required_fields:
          gate_result: "pass"
        bug_object_schema:
          bug_id: "string"
    """
)


def write_yaml(tmp: Path, body: str) -> Path:
    p = tmp / "guardrails.yaml"
    p.write_text(body, encoding="utf-8")
    return p


def run_validate_text(body: str) -> tuple[int, dict]:
    """Helper: write body to a temp file, run validator, return (rc, json)."""
    with tempfile.TemporaryDirectory() as tmp:
        path = write_yaml(Path(tmp), body)
        proc = run_validator(path)
    try:
        payload = json.loads(proc.stdout) if proc.stdout else {}
    except json.JSONDecodeError:
        payload = {"_raw": proc.stdout, "_stderr": proc.stderr}
    return proc.returncode, payload


# =============================================================================
# Happy path: the real v2.0.0 file must pass.
# =============================================================================
class RealFixtureTests(unittest.TestCase):
    def test_real_v2_config_passes(self) -> None:
        self.assertTrue(REAL_CONFIG.exists(), msg=f"missing: {REAL_CONFIG}")
        proc = run_validator(REAL_CONFIG)
        self.assertEqual(proc.returncode, 0, msg=proc.stdout + proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["status"], "PASS")
        self.assertEqual(payload["version"], "2.0.0")

    def test_minimal_fixture_passes(self) -> None:
        rc, payload = run_validate_text(MINIMAL_VALID)
        self.assertEqual(rc, 0, msg=json.dumps(payload, indent=2))
        self.assertEqual(payload["status"], "PASS")


# =============================================================================
# Top-level field / version enforcement
# =============================================================================
class TopLevelFieldTests(unittest.TestCase):
    def test_missing_orchestrator_field_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "orchestrator: vnpt-qa-tester-orchestrator\n", ""
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("missing required top-level field 'orchestrator'" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_missing_version_field_fails(self) -> None:
        body = MINIMAL_VALID.replace("version: 2.0.0\n", "")
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("missing required top-level field 'version'" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_non_semver_version_fails(self) -> None:
        body = MINIMAL_VALID.replace("version: 2.0.0\n", "version: v2\n")
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("version must be semver" in f for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_orchestrator_wrong_type_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "orchestrator: vnpt-qa-tester-orchestrator\n",
            "orchestrator: 123\n",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("orchestrator must be a string" in f for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# Guardrail booleans
# =============================================================================
class GuardrailBoolTests(unittest.TestCase):
    def test_missing_guardrail_bool_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "allow_phase_skip: false\n", ""
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("missing guardrail bool 'allow_phase_skip'" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_guardrail_bool_wrong_type_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "allow_phase_skip: false\n", "allow_phase_skip: \"false\"\n"
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("allow_phase_skip must be a bool" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# response_style
# =============================================================================
class ResponseStyleTests(unittest.TestCase):
    def test_missing_response_style_fails(self) -> None:
        body = "\n".join(
            line for line in MINIMAL_VALID.splitlines()
            if not line.startswith("response_style") and
               not line.startswith("  required_sections") and
               not line.startswith("    - Inputs Read") and
               not line.startswith("    - Decisions") and
               not line.startswith("  forbidden_behaviors") and
               not line.startswith("    - skip_phases")
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("response_style must be a mapping" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_unknown_key_in_response_style_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "forbidden_behaviors:\n",
            "forbidden_behaviors:\n",
        )
        # Insert an unknown key
        body = body.replace(
            "  forbidden_behaviors:\n    - skip_phases_because_task_feels_simple",
            "  forbidden_behaviors:\n    - skip_phases_because_task_feels_simple\n  unknown_key: 1",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("response_style has unknown keys" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_empty_required_sections_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "  required_sections:\n    - Inputs Read\n    - Decisions\n",
            "  required_sections: []\n",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("response_style.required_sections must be a non-empty list" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# traceability
# =============================================================================
class TraceabilityTests(unittest.TestCase):
    def test_missing_traceability_key_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "  require_generated_from: true\n", ""
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("traceability.require_generated_from is required" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_unknown_traceability_key_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "  require_generated_from: true\n",
            "  require_generated_from: true\n  require_unicorns: true\n",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("traceability has unknown keys" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# test_id_prefixes
# =============================================================================
class TestIdPrefixTests(unittest.TestCase):
    def test_missing_prefix_fails(self) -> None:
        body = MINIMAL_VALID.replace("QA-EXP-: exploratory/manual\n", "")
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("test_id_prefixes missing keys" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_unknown_prefix_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "QA-EXP-: exploratory/manual\n",
            "QA-EXP-: exploratory/manual\n  QA-NEW-: new prefix\n",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("test_id_prefixes has unknown keys" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# minimum_per_risk
# =============================================================================
class MinPerRiskTests(unittest.TestCase):
    def test_negative_int_in_min_per_risk_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "happy_path: 1\n", "happy_path: -1\n"
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("minimum_per_risk.P0.happy_path must be a non-negative int" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_missing_p1_section_fails(self) -> None:
        body = "\n".join(
            line for line in MINIMAL_VALID.splitlines()
            if not line.startswith("  P1:") and
               not line.startswith("    main_path_tests: 1")
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("minimum_per_risk missing keys" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# medium_model_decomposition
# =============================================================================
class MediumModelDecompTests(unittest.TestCase):
    def test_unknown_key_in_decomp_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "  max_gap_unresolved: 3\n",
            "  max_gap_unresolved: 3\n  banana: true\n",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("medium_model_decomposition has unknown keys" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_max_gap_unresolved_negative_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "max_gap_unresolved: 3\n", "max_gap_unresolved: -1\n"
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("max_gap_unresolved must be a non-negative int" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# minimax_m2_7_constraints envelope
# =============================================================================
class Mm27EnvelopeTests(unittest.TestCase):
    def test_unknown_key_in_mm27_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "  gate_report_json_schema:\n",
            "  mystery_block: 1\n  gate_report_json_schema:\n",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("minimax_m2_7_constraints has unknown keys" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# Non-empty list keys
# =============================================================================
class NonEmptyListTests(unittest.TestCase):
    def test_empty_required_bug_classes_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "required_bug_classes_to_consider:\n  - wrong_state_transition\n",
            "required_bug_classes_to_consider: []\n",
        )
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1)
        self.assertTrue(
            any("required_bug_classes_to_consider must be a non-empty list" in f
                for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# Placeholder detection
# =============================================================================
class PlaceholderDetectionTests(unittest.TestCase):
    """The validator must fail fast on unresolved placeholders / template
    tokens in config values. Code templates under
    `minimax_m2_7_constraints.automation_code_templates` are exempt by design.
    """

    def _assert_placeholder_detected(
        self, body: str, expected_substring: str
    ) -> None:
        rc, payload = run_validate_text(body)
        self.assertEqual(rc, 1, msg=json.dumps(payload, indent=2))
        matches = [
            f for f in payload["failures"] if expected_substring in f
        ]
        self.assertTrue(
            matches,
            msg=f"expected placeholder {expected_substring!r} in failures; "
                f"got {payload['failures']}",
        )

    def test_todo_in_top_level_scalar_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: TODO\n",
        )
        self._assert_placeholder_detected(body, "TODO")

    def test_tbd_in_list_value_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "  - SPEC_AMBIGUITY\n",
            "  - TBD\n",
        )
        self._assert_placeholder_detected(body, "TBD")

    def test_fixme_in_top_level_scalar_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: FIXME\n",
        )
        self._assert_placeholder_detected(body, "FIXME")

    def test_xxx_marker_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: XXX\n",
        )
        self._assert_placeholder_detected(body, "XXX")

    def test_lorem_ipsum_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: lorem ipsum dolor sit amet\n",
        )
        self._assert_placeholder_detected(body, "lorem ipsum")

    def test_changeme_token_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: CHANGEME\n",
        )
        self._assert_placeholder_detected(body, "CHANGEME")

    def test_replace_me_token_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: REPLACE_ME\n",
        )
        self._assert_placeholder_detected(body, "REPLACE_ME")

    def test_handlebars_placeholder_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: 'Reduce drift {{phase_name}}'\n",
        )
        self._assert_placeholder_detected(body, "handlebars")

    def test_shell_style_placeholder_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: 'reduce drift ${PHASE}'\n",
        )
        self._assert_placeholder_detected(body, "shell-style")

    def test_your_token_bracket_fails(self) -> None:
        body = MINIMAL_VALID.replace(
            "purpose: Reduce drift and make skipped steps obvious\n",
            "purpose: 'reduce drift [YOUR_NAME]'\n",
        )
        self._assert_placeholder_detected(body, "[YOUR_*]")

    def test_code_template_placeholder_exempt(self) -> None:
        """`<FeatureName>` inside automation_code_templates is the point of
        code templates. Must NOT trigger a placeholder failure."""
        body = MINIMAL_VALID  # MINIMAL_VALID already contains the <FeatureName> template
        rc, payload = run_validate_text(body)
        self.assertEqual(
            rc, 0,
            msg="automation_code_templates placeholders must be exempt; "
                f"got {json.dumps(payload, indent=2)}",
        )

    def test_placeholder_outside_template_subtree_fails(self) -> None:
        """A placeholder in a sibling field (e.g. `command_templates`) must
        still be caught — the exemption is narrow."""
        body = MINIMAL_VALID.replace(
            'test: "pytest -v 2>&1"\n',
            'test: "pytest -v {{cov}} 2>&1"\n',
        )
        self._assert_placeholder_detected(body, "handlebars")


# =============================================================================
# CLI behavior
# =============================================================================
class CliTests(unittest.TestCase):
    def test_no_args_exits_2(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(VALIDATOR)],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("Usage:", proc.stderr)

    def test_missing_file_exits_2(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(VALIDATOR), "Z:/does-not-exist.yaml"],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("not found", proc.stderr)

    def test_malformed_yaml_exits_1(self) -> None:
        # Migration-guide indentation bug reproduced
        body = textwrap.dedent(
            """\
            orchestrator: vnpt-qa-tester-orchestrator
            profile: x
            version: 1.0.0
            deprecated_versions:
              - "0.9.0"
              migration_guide: |
                Should be top-level
            """
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad.yaml"
            path.write_text(body, encoding="utf-8")
            proc = run_validator(path)
        self.assertEqual(proc.returncode, 1)
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["status"], "FAIL")
        self.assertTrue(
            any("YAML parse error" in f for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )

    def test_empty_file_exits_1(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "empty.yaml"
            path.write_text("", encoding="utf-8")
            proc = run_validator(path)
        self.assertEqual(proc.returncode, 1)
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["status"], "FAIL")
        self.assertTrue(
            any("empty" in f for f in payload["failures"]),
            msg=json.dumps(payload, indent=2),
        )


# =============================================================================
# Direct unit-level coverage for the in-process validate() helper. Catches
# regressions that the CLI subprocess tests would also catch but with a
# crisper traceback.
# =============================================================================
class ValidateUnitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.mod = load_module(VALIDATOR, "validate_guardrails")

    def _validate(self, data) -> list[str]:
        return self.mod.validate(data, source=Path("<test>"))

    def test_non_dict_top_level_fails(self) -> None:
        failures = self._validate([1, 2, 3])
        self.assertEqual(len(failures), 1)
        self.assertIn("top-level must be a mapping", failures[0])

    def test_empty_dict_fails_on_all_required_top_level(self) -> None:
        failures = self._validate({})
        required = {"orchestrator", "profile", "version"}
        missing = {
            f"missing required top-level field '{k}'" for k in required
        }
        for m in missing:
            self.assertTrue(
                any(m in f for f in failures),
                msg=f"expected {m!r} in {failures}",
            )

    def test_placeholder_scan_marks_path(self) -> None:
        # Schema is mostly empty so we get a clean placeholder-only error.
        data = {
            "orchestrator": "x",
            "profile": "x",
            "version": "1.0.0",
            "phase_order_is_mandatory": True,
            "allow_phase_skip": False,
            "allow_automation_before_oracle": False,
            "allow_generic_placeholders_as_final": False,
            "allow_silent_assumptions": False,
            "allow_shallow_tests_to_count": False,
            "response_style": {
                "required_sections": ["Inputs Read"],
                "forbidden_behaviors": ["skip_phases_because_task_feels_simple"],
            },
            "traceability": {
                "require_test_id": True,
                "require_risk_id": True,
                "require_oracle_id": True,
                "require_requirement_id_when_available": True,
                "require_generated_from": True,
            },
            "test_id_prefixes": {
                "QA-EX-": "a", "QA-COMB-": "a", "QA-SM-": "a", "QA-PROP-": "a",
                "QA-API-": "a", "QA-E2E-": "a", "QA-REG-": "a", "QA-EXP-": "a",
            },
            "minimum_per_risk": {"P0": {"x": 1}, "P1": {"x": 1}},
            "required_bug_classes_to_consider": ["x"],
            "labels_for_uncertainty": ["x"],
            "patterns_that_do_not_count": ["x"],
            "what_counts_as_coverage": ["x"],
            "self_review_required_before_final_report": True,
            "self_review_checklist": ["x"],
            "require_phase_trace_table": True,
            "medium_model_decomposition": {
                "enabled": True,
                "table_per_phase": True,
                "purpose": "TODO",  # placeholder lives here
                "max_gap_unresolved": 1,
            },
        }
        failures = self._validate(data)
        self.assertTrue(
            any("TODO" in f and "medium_model_decomposition.purpose" in f
                for f in failures),
            msg=json.dumps(failures, indent=2),
        )


if __name__ == "__main__":
    unittest.main()
