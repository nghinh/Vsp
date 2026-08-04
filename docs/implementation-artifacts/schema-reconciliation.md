# Schema Reconciliation — Flyway migrations vs JPA entities

**Status:** open (major follow-up) · **Discovered:** 2026-08-05 (runtime readiness pass)

## Problem

The Flyway migration set and the JPA entities disagree on primary-key types for the
**course / round / tournament** domain:

| Table | Flyway migration PK | Entity `@Id` (and API / repo / DTO) |
| --- | --- | --- |
| `golf_facilities`, `courses`, `holes` | `UUID` (`gen_random_uuid()`) | `Long` (`GenerationType.IDENTITY`) |
| `rounds`, `scores` | `UUID` | `Long` |
| tournaments and dependents | `UUID` | mixed (some `UUID`, some `Long`) |

All application code — entities, `JpaRepository<T, Long>`, `@PathVariable Long`, DTOs, the
OpenAPI contract — uses `Long`. The migrations use `UUID`. The two cannot coexist: on
PostgreSQL a `find(Course, 1L)` issues `WHERE id = 1` against a `uuid` column and fails.

**Why it was invisible until now:** the API unit/integration tests use H2 with
`ddl-auto=create-drop` (schema generated from the *entities*, so `bigint`) and Flyway
**disabled**. So 636 tests pass while the Flyway-based schema is unusable. It only surfaced by
booting the app against the docker-compose PostgreSQL.

## Interim resolution (implemented) — DEV runs on the entity schema

`application-dev.yml`:
- `spring.flyway.enabled: false`
- `spring.jpa.hibernate.ddl-auto: update`
- `spring.jpa.defer-datasource-initialization: true` + `spring.sql.init` → `db/seed/dev-seed.sql`
  (re-seeds the 6 RBAC roles that V9 used to insert).

This makes DEV run on exactly the schema the entities/tests use (all `bigint`), so every
entity-backed feature works. Verified end-to-end: registration, profile, bag, course search,
nearby (PostGIS), markets, etc. — no 500s.

## Prod / staging — the real fix (not yet done)

DEV no longer uses Flyway, but staging/prod still do, and the Flyway schema is broken. Pick ONE
source of truth and make both sides agree, then re-enable Flyway in dev:

- **Option A (recommended): migrations → `bigint`.** Rewrite the course/round/tournament
  migrations (≈V13, V16–V32) to use `BIGINT`/`BIGSERIAL` identity PKs and `bigint` FK columns,
  matching the pervasive `Long` code. Largest churn is in SQL, none in Java.
- **Option B: entities → `UUID`.** Change the course/round/tournament entities, repos,
  controllers, DTOs and the API contract to `UUID`. Much larger code churn and an API-contract change.

After reconciling, re-enable Flyway everywhere and drop the dev `ddl-auto`/seed override.

## Related runtime fixes made in the same pass
- DB defaults `vhgp` → `vsp` (match docker-compose).
- Dev JWT secret default (was empty → `WeakKeyException`).
- Missing package-table migration (V32) — superseded by the ddl-auto dev approach, kept for the
  Flyway path.
- Lazy-create GET endpoints (`/profiles/me`, `/bags`) were `@Transactional(readOnly=true)` yet
  INSERT → made writable.
- `NoResourceFoundException` (unmatched route) now returns **404**, not a generic 500.
- PostGIS native queries used `::geometry`/`::geography`; Hibernate mangles `::` → fixed to
  `CAST(x AS geography)` and made `ST_DWithin`/`ST_Distance` consistently geography (meters).
