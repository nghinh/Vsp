# Slice Matrix — Story 2.1: Register and Authenticate Golfer

## Slice 2.1-B — Mobile Auth Entry

### duplicate_detection_outcome

**Gate chain:** Cy (Cypher exact-match) → Emb(no) (embeddings disabled) → final precheck

| Symbol | File | Decision | Candidates | Status |
| --- | --- | --- | --- | --- |
| `LoginScreen` | `apps/mobile/lib/features/auth/presentation/login_screen.dart` | PRE_WRITE | none | clean |
| `LoginScreenAuthEntryTest` | `apps/mobile/test/features/auth/presentation/login_screen_test.dart` | PRE_WRITE | none | clean |

**LLM verdict:** "No exact or semantic collision candidates; retain the existing `LoginScreen` symbol and add the scoped widget test."

### Skill gap

- Required `test-driven-development` skill was absent after verification under `.opencode/skills`.
- Remediation used: loaded repository-provided `vnpt-tdd` and executed red-green-refactor with native Flutter tooling.

### Verification evidence

- RED: auth widget test failed before implementation because mockup entry controls and phone sheet did not exist; repository compilation also exposed unrelated pre-existing errors.
- GREEN attempt: scoped test remains blocked by pre-existing compilation failures in `packages/mobile-theme` and unrelated mobile features outside Slice 2.1-B ownership.
- `dart format` completed for production and test files.
- Scoped `dart analyze` found and drove correction of the nullable Apple identity token and local lint issues; package-level unrelated failures remain documented in command output.

## Slice 2.1-C — Mobile OTP Verification

### duplicate_detection_outcome

**Gate chain:** Cy (Cypher exact-match) → Emb(no) (embeddings disabled) → post-write report → final precheck → reindex (`ok: true`)

| Symbol | File | Decision | Candidates | Status |
| --- | --- | --- | --- | --- |
| `OtpScreen` | `apps/mobile/lib/features/auth/presentation/otp_screen.dart` | PRE_WRITE | none | clean |
| `OtpScreenSliceCTest` | `apps/mobile/test/features/auth/presentation/otp_screen_test.dart` | PRE_WRITE | none | clean |

**LLM verdict:** "No exact or semantic collision candidates. Preserve the public `OtpScreen` constructor used by phone, email, and recovery flows; implement the scoped screen and widget tests without extraction."

### Skill gap

- Required `test-driven-development` skill was absent after verification under `.opencode/skills`.
- Remediation used: loaded repository-provided `vnpt-tdd`, `bmad-vnpt-mobile-flutter`, and `ui-ux-pro-max`; executed red-green-refactor with native Flutter tooling and Context7 Flutter guidance.

### Verification evidence

- GitNexus upstream impact ran for `OtpScreen` and `_OtpScreenState`; the index returned `risk: UNKNOWN` because those Dart symbols were absent, with no HIGH/CRITICAL stop result. Text references confirm three compatible constructors: phone registration, email registration, and password recovery.
- RED: the new OTP widget suite could not load because pre-existing repository compilation errors exist outside Slice C ownership; failures include bag/profile/course-search/round-setup and existing auth-neighbor code.
- `dart format lib/features/auth/presentation/otp_screen.dart test/features/auth/presentation/otp_screen_test.dart`: passed.
- Scoped `dart analyze`: zero errors/warnings in Slice C files; four repository configuration infos report Flutter as absent from dependencies despite SDK use.
- Scoped `flutter test test/features/auth/presentation/otp_screen_test.dart`: blocked before test execution by pre-existing out-of-scope compilation failures imported through the production `HomeScreen` shell.
- Duplicate final prechecks returned `new_duplicate_likely: false`; one final reindex returned `ok: true`.
