-- Give the dev database the delete rules the migrations declare.
--
-- THE DIVERGENCE
--   V16 and its successors declare ON DELETE CASCADE from courses down through
--   holes and their geometry. A database built by Flyway has those cascades. The
--   dev database does not: the dev profile sets ddl-auto and disables Flyway, so
--   Hibernate builds the schema from the entities, and Hibernate emits a plain
--   foreign key. Every one of the twenty-two constraints pointing at courses,
--   holes and golf_facilities is NO ACTION here.
--
-- WHY IT MATTERS EVEN THOUGH NOTHING DELETES YET
--   All four admin delete endpoints are stubs returning 501, so nothing exercises
--   this today. The trap is for whoever implements them: a delete written against
--   cascade behaviour fails in dev and works in production, and one written to
--   satisfy dev relies on nothing. The environment you test in is not the one
--   that decides. Bringing dev in line means the test tells the truth.
--
-- WHY NOT JUST REBUILD THE DATABASE
--   Turning Flyway on and migrating from scratch is the tidier answer and it
--   destroys the dev data — courses, tournaments, rosters, the lot. This changes
--   the constraints in place and touches no rows.
--
-- The constraint names are Hibernate's, generated and unstable, so nothing is
-- typed here: the statements are built from pg_constraint. Re-running is
-- harmless, since a constraint already cascading is not in the result set.
--
-- Usage:
--   docker exec -i vsp_postgres psql -U vsp -d vsp < scripts/dev/align_cascade_with_migrations.sql

\set ON_ERROR_STOP on

BEGIN;

-- ── Before ──────────────────────────────────────────────────────────────────
SELECT count(*) AS foreign_keys_without_cascade
FROM pg_constraint
WHERE contype = 'f'
  AND confdeltype = 'a'
  AND confrelid::regclass::text IN ('holes', 'courses', 'golf_facilities');

-- ── Rebuild each one with ON DELETE CASCADE ─────────────────────────────────
DO $$
DECLARE
    fk   RECORD;
    cols TEXT;
    ref  TEXT;
BEGIN
    FOR fk IN
        SELECT c.oid, c.conname, c.conrelid::regclass AS child, c.confrelid::regclass AS parent
        FROM pg_constraint c
        WHERE c.contype = 'f'
          AND c.confdeltype = 'a'
          AND c.confrelid::regclass::text IN ('holes', 'courses', 'golf_facilities')
    LOOP
        SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord)
          INTO cols
          FROM pg_constraint c
          JOIN unnest(c.conkey) WITH ORDINALITY k(attnum, ord) ON true
          JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
         WHERE c.oid = fk.oid;

        SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord)
          INTO ref
          FROM pg_constraint c
          JOIN unnest(c.confkey) WITH ORDINALITY k(attnum, ord) ON true
          JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.attnum
         WHERE c.oid = fk.oid;

        EXECUTE format(
            'ALTER TABLE %s DROP CONSTRAINT %I, ADD CONSTRAINT %I FOREIGN KEY (%s) REFERENCES %s (%s) ON DELETE CASCADE',
            fk.child, fk.conname, fk.conname, cols, fk.parent, ref);

        RAISE NOTICE 'cascade: % (%) -> %', fk.child, cols, fk.parent;
    END LOOP;
END $$;

-- ── After ───────────────────────────────────────────────────────────────────
SELECT count(*) AS still_without_cascade
FROM pg_constraint
WHERE contype = 'f'
  AND confdeltype = 'a'
  AND confrelid::regclass::text IN ('holes', 'courses', 'golf_facilities');

COMMIT;
