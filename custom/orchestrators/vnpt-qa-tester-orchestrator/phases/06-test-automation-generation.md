# Phase: 06-test-automation-generation

## Purpose

Convert test intent into runnable unit/component/integration/API/property/E2E tests with fixtures and commands.

## Required inputs

- outputs from all earlier phases
- relevant project files read from 0-EOF
- current risk map and oracle where applicable

## Required work

- test files
- fixtures/seeds
- mocks/stubs justification
- commands
- test ID to file mapping
- assertion mapping
- flaky risk controls

## Required output

`docs/qa/<feature>/06-automation-map.md`

## Exit criteria

- the named output artifact exists
- content is project-specific, not a generic template
- traceability to requirement/risk/oracle is preserved
- P0/P1 risks are not silently skipped
- assumptions and ambiguities are explicitly recorded

## Anti-gaming checks

- do not count shallow tests as coverage
- do not proceed to automation when oracle is missing
- do not hide tool failure; write fallback plan and reason
- do not invent expected behavior when requirement is ambiguous; mark SPEC_AMBIGUITY

## Medium-model strict checklist

Before leaving this phase, the agent must produce the following mini audit:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|

Hard rules:

- Do not use generic TODO/placeholders as final content.
- Do not hide uncertainty. Use `SPEC_AMBIGUITY`, `ORACLE_GAP`, `ENV_GAP`, `DATA_GAP`, `TOOL_GAP`, or `JUSTIFIED_EXCEPTION`.
- Maintain stable IDs and traceability.
- Do not count shallow tests as coverage.

## Stack-specific command templates (M2.7 reference)

Use these exact templates as starting points. Replace placeholder comments with real logic.

### TypeScript/Node (Jest)
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

### Python (pytest)
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

### Go
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

### Playwright E2E (text assertions only — no screenshots)
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
