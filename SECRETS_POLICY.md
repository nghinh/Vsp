# Secrets Scanning Policy

## Overview

This repository enforces a **zero-tolerance policy** on committed secrets. Automated secret scanning runs on every push and pull request via [Gitleaks](https://github.com/zricethezav/gitleaks) through the `ci-secrets.yml` workflow.

## Scanning Tools

| Tool | Purpose | Workflow |
|---|---|---|
| [Gitleaks](https://github.com/zricethezav/gitleaks-action) (`zricethezav/gitleaks-action`) | Scan repository, commits, and PR diffs for secrets | `ci-secrets.yml` (all pushes), per-app workflows (`ci-mobile.yml`, `ci-portal.yml`, `ci-api.yml`) |

## Policy

1. **No secrets in code** — API keys, tokens, passwords, private keys, and other credentials must never be committed to any branch.
2. **Use environment variables** — Runtime secrets are injected via environment variables or a secrets manager (e.g., GitHub Actions secrets, AWS Secrets Manager, HashiCorp Vault).
3. **Use `.env.example`** — Document required environment variables in `.env.example` or `setupLocalEnv.sh` with empty/mocked values.
4. **Baseline exceptions** — Known false positives may be added to `.gitleaks-baseline.json` in the root directory. This file must be reviewed and approved in the same PR as the exception.

## Allowed Patterns

The following are permitted **only when they are test/dummy values** (e.g., `your-api-key-here`, `test-only-key`, `postgres://localhost:5432`):

- Placeholder strings in `.env.example` and `setupLocalEnv.sh`
- Test credentials in `test/` and `integration_test/` directories
- Documentation examples prefixed with `EXAMPLE:` or `TESTONLY:`

## Workflow Execution

### Repository-wide (every push)
The `ci-secrets.yml` workflow scans the entire repository on every push to `main` or `develop` and on every pull request.

### Per-app (on relevant paths change)
Each application workflow also runs Gitleaks:
- `ci-mobile.yml` — triggers on changes to `apps/mobile/**`
- `ci-portal.yml` — triggers on changes to `apps/portal/**`
- `ci-api.yml` — triggers on changes to `apps/api/**`

## Handling Findings

If a secret is detected:

1. **Immediately rotate** the exposed credential at the provider.
2. **Remove the secret** from git history using `git filter-repo` or BFG Repo-Cleaner.
3. **File a security incident report** per your organization's security policy.
4. **Add a baseline exception** in `.gitleaks-baseline.json` if the finding is a false positive (requires security team approval).

## Related Files

- `.gitleaks-baseline.json` — Baseline exceptions (approved false positives)
- `infra/scripts/setupLocalEnv.sh` — Environment variable template
- `SECRETS_POLICY.md` — This document

## References

- [Gitleaks documentation](https://github.com/zricethezav/gitleaks)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Secret scanning](https://docs.github.com/en/code-security/secret-scanning)
