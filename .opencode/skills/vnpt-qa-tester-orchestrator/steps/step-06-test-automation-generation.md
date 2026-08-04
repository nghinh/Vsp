# Step 06: Test Automation Generation

**Goal:** Convert test intent into runnable unit/component/integration/API/property/E2E tests with fixtures and commands. This step is the boundary between planning and execution — no test file may be written before its oracle exists in step-05.

## Prerequisites

- `05-test-oracle.md` exists and every executable test has at least one oracle ID.
- Stack detected by `00-qa-mission.md` and confirmed by `scripts/detect_stack.py`.
- `qa-state.json` `phase_status = "test_oracle_design"`.

## Sequence

### Step 6.1 — Detect stack and pick command templates

Use `scripts/detect_stack.py` when available, otherwise inspect `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `pom.xml`, `build.gradle`, `go.mod`, `composer.json`. From the detected stack, pull the exact commands from `config/medium-model-guardrails.yaml` Section 11:

| Stack | test | lint | type_check | build | e2e | mutation |
|---|---|---|---|---|---|---|
| typescript_node | `npm test -- --coverage --reporters=text 2>&1` | `npx eslint . --ext .ts,.tsx 2>&1 \| head -100` | — | `npm run build 2>&1` | `npx playwright test --reporter=list 2>&1` | `npx stryker run 2>&1` |
| python | `pytest -v --tb=short --cov=. --cov-report=term-missing 2>&1` | `python -m flake8 . 2>&1 \| head -100 \|\| ruff check . 2>&1 \| head -100` | `mypy . 2>&1 \| head -100` | — | — | `mutmut run 2>&1 && mutmut results 2>&1` |
| golang | `go test ./... -v -cover 2>&1` | `go vet ./... 2>&1` | — | `go build ./... 2>&1` | — | `go test -race ./... 2>&1` |
| rust | `cargo test 2>&1` | `cargo clippy -- -D warnings 2>&1` | — | `cargo build 2>&1` | — | — |
| java_kotlin | `./gradlew test 2>&1 \|\| mvn test 2>&1` | — | — | `./gradlew build 2>&1 \|\| mvn package 2>&1` | — | — |
| php | `vendor/bin/phpunit --testdox 2>&1` | `vendor/bin/phpstan analyse 2>&1 \| head -100` | — | — | — | — |
| vue_react_angular | `npm test -- --watchAll=false --coverage 2>&1` | — | — | — | `npx playwright test --reporter=list 2>&1 \|\| npx cypress run 2>&1` | — |

### Step 6.2 — Apply the oracle-first gate

For every executable test:

- IF oracle exists → generate the executable test using the stack template.
- IF oracle is missing → STOP. Go back to step 05, write the oracle first.
- IF stack is not detected → run `ls package.json go.mod requirements.txt Cargo.toml pom.xml build.gradle` and pick the dominant stack. If still ambiguous, record `TOOL_GAP`.

### Step 6.3 — Apply the per-stack code template

Use the templates from `config/medium-model-guardrails.yaml` Section 11. Replace placeholders with real logic, never ship placeholder code as final.

#### TypeScript / Node (Jest)

```typescript
import { describe, it, expect } from '@jest/globals';
describe('<FeatureName>', () => {
  it('QA-EX-001: should <expected> (Risk: RISK-001, Oracle: ORACLE-001)', () => {
    // Arrange / Act / Assert
    expect(result).toBe(expected);
  });
  it('QA-EX-002: should reject <invalid input>', () => {
    expect(() => fn(badInput)).toThrow('<message>');
  });
});
```

Run: `npm test -- --coverage --reporters=text 2>&1`

#### Python (pytest)

```python
import pytest
class TestFeatureName:
    def test_QA_EX_001_happy_path(self):  # Risk: RISK-001 | Oracle: ORACLE-001
        assert fn(valid) == expected
    def test_QA_EX_002_negative_invalid_input(self):
        with pytest.raises(ValueError, match="<msg>"):
            fn(invalid)
```

Run: `pytest -v --tb=short --cov=. --cov-report=term-missing 2>&1`

#### Go

```go
func TestFeatureName_HappyPath(t *testing.T) { // QA-EX-001 | Risk: RISK-001 | Oracle: ORACLE-001
    got, err := Fn(valid)
    if err != nil { t.Fatal(err) }
    if got != want { t.Errorf("got %v want %v", got, want) }
}
func TestFeatureName_NegativeInvalid(t *testing.T) { // QA-EX-002
    _, err := Fn(invalid)
    if err == nil { t.Error("expected error") }
}
```

Run: `go test ./... -v -cover 2>&1`

#### Playwright E2E (text assertions only — no screenshots)

```typescript
import { test, expect } from '@playwright/test';
test('QA-E2E-001: <scenario> (Risk: RISK-001, Oracle: ORACLE-001)', async ({ page }) => {
  await page.goto('/path');
  await page.getByRole('button', { name: 'Submit' }).click();
  await expect(page.getByText('Success')).toBeVisible(); // text assertion
  const res = await page.waitForResponse('/api/endpoint');
  expect(res.status()).toBe(200);
});
```

Run: `npx playwright test --reporter=list 2>&1`

**CRITICAL (M2.7):** Do NOT use `page.screenshot()`. All assertions must be text-based.

### Step 6.4 — Build the automation map

For every executable test:

- test file path
- test function name
- assertions with line numbers
- fixtures / seeds consumed
- mocks / stubs (only with justification)
- runnable command
- environment notes
- mapping: test ID → file → assertion → oracle → risk

### Step 6.5 — Write `docs/qa/<scope>/06-automation-map.md`

The file MUST contain:

- per-test automation entry from step 6.4
- the runnable commands per stack
- the flaky-risk controls (test isolation, deterministic ordering, timeouts, retries)
- a forward pointer to step-07-test-execution

## Required inputs

- outputs from earlier phases — all `04a-04k` artifacts and `05-test-oracle.md`.
- relevant project files read from 0-EOF.
- current risk map and oracle where applicable — oracle map is the active reference.

## Required work (deliverables for this step)

- test files
- fixtures / seeds
- mocks / stubs with justification
- commands
- test ID → file mapping
- assertion mapping
- flaky-risk controls

## Required output

`docs/qa/<scope>/06-automation-map.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved — every test file has `risk_ids` and `oracle_ids` in comments
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded
- tests are executable
- tests map back to oracle and risk
- tests contain business assertions
- tests avoid superficial pass criteria

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark `SPEC_AMBIGUITY`
- do not use `page.screenshot()` or any image-based evidence (M2.7 constraint)

## Medium-model strict checklist

Before leaving this step, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.

## State writes

Update `qa-state.json`:

```json
{
  "current_step": "step-06-test-automation-generation",
  "phase_status": "test_automation_generation",
  "scope_artifacts": {
    "06-automation-map.md": "written"
  },
  "automation_summary": {
    "executable_tests": <int>,
    "manual_only_tests": <int>,
    "tests_with_business_assertion": <int>,
    "tests_with_shallow_assertion_only": <int>,
    "mocks_used_with_justification": <int>
  }
}
```

## Hard stops

- Never write an executable test whose oracle does not exist in `05-test-oracle.md`.
- Never use `page.screenshot()` or any image-based evidence (M2.7 constraint) — write `TOOL_GAP` with the exact command that would capture visual evidence.
- Never accept a mock that hides the system under test without `JUSTIFIED_EXCEPTION` and a behavioral fallback assertion.
- Never accept a test that only checks status 200 / page render / snapshot / mock call.
- Never accept a flaky-risk control that relies on `sleep`; use deterministic waits or event-based synchronization.

## Next step

Proceed to `step-07-test-execution.md`. Only load that file when the automation exit criteria above are satisfied. Never load multiple step files simultaneously.
