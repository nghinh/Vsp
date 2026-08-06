-- V0__baseline.sql
-- Installs the PostGIS extension every later migration depends on.
--
-- This file used to be called 001_baseline.sql. Flyway's sqlMigrationPrefix is
-- "V", so "001_baseline.sql" matched nothing: Flyway logged "1 SQL migrations
-- were detected but not run because they did not follow the filename
-- convention" at INFO and carried on. PostGIS was therefore never created, and
-- V16 died on its first spatial index with "function st_geomfromwkb(bytea) does
-- not exist" — taking V16 through V33 with it. Nothing caught this because dev
-- runs on Hibernate ddl-auto and the test suite runs H2 with Flyway disabled,
-- so no environment had ever executed this migration set.
--
-- V0 rather than a renumber, so the existing V1..V33 keep their versions.
-- Note that spring.flyway.baseline-on-migrate must stay false (see
-- application.yml): baselining marks the schema as being at baseline-version,
-- which defaults to 1, and would skip this file.

CREATE EXTENSION IF NOT EXISTS postgis;

-- The `schema_version` table this file used to create is deliberately gone.
-- It was a hand-rolled copy of Flyway 4's history table, written to by nobody
-- and read by nobody — Flyway 9 keeps its history in `flyway_schema_history`.
-- Two version tables side by side, only one of them real, is how you end up
-- believing a migration ran.
