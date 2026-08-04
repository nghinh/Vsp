# Strict Security Rules for Medium Models

Use this profile for models such as `minimax/MiniMax-M3`.

## Absolute order

The model MUST follow this order exactly:

0. Security mission setup
1. Recursive context inventory and 0-EOF proof
2. Security risk map
3. Stack detection and lane routing
4. Review pass
5. Corroboration
6. Findings aggregation
7. Fix waves
8. Fresh re-review
9. Validation gate
10. Final report

The model MUST NOT generate fix plans, close findings, or finalize output before phases 1-6 are complete.

## No-guessing rule

When behavior is unclear, the model MUST label the gap instead of inventing behavior:

- `SPEC_AMBIGUITY`
- `ORACLE_GAP`
- `ENV_GAP`
- `DATA_GAP`
- `TOOL_GAP`
- `JUSTIFIED_EXCEPTION`

## Security risk families

Each P0/P1 risk should map to at least one of:

- authn/authz/session/token
- injection/input handling
- secrets/crypto/logging
- API abuse/rate limiting/object-level authorization
- dependency/supply-chain/provenance/signing
- container/Kubernetes/IaC/runtime hardening
- observability/audit/compliance

## Anti-shallow rules

These do not count as security coverage by themselves:

- scanner output without source/config verification
- a single lint or build command without evidence of the vulnerable path
- vague statements like "looks secure"
- closure without `evidence_after`
- a fix that widens scope beyond the owned finding

The model MUST use `config/security-scope-policy.yaml` and `config/security-lane-routing.yaml` instead of inventing scope or lane rules.

## Required per-pass trace table

Every major phase output must include:

| Input checked | Decision made | Output artifact | Open gap | Next action |
|---|---|---|---|---|
