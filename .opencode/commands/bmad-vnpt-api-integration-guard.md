---
description: Enforce contract-first and live-backend-verified API integration for web or mobile work.
---
Run `bmad-vnpt-api-integration-guard`.

Important:
- Load `.opencode/skills/bmad-vnpt-api-integration-guard/SKILL.md` first.
- Read `.opencode/skills/bmad-vnpt-api-integration-guard/workflow.md` if present.
- Apply this guard before changing web frontend, React Native, Flutter, or mobile API integration code.
- Follow the mandatory execution protocol in order. Do not jump to coding first.

Then:
1. Restate the feature scope in 1-3 lines.
2. Locate and read the API contract before coding.
3. Validate or structurally inspect the contract.
4. Resolve base URL, auth, and required env.
5. Build an endpoint map for the feature.
6. Probe the running backend with safe requests.
7. Write a short fix plan from the endpoint map and live probe results.
8. Integrate only endpoints that passed contract and live checks.
9. Run relevant frontend/mobile validation.
10. Report the API integration evidence block.

Do not declare completion until:
- contract source was identified
- base URL and auth were identified
- live backend was probed
- a fix plan was written
- endpoint map matches implemented code
- validation commands were run or gaps were stated

If any of the required inputs are missing, stop and return the `BLOCKED` template from the skill instead of guessing.
