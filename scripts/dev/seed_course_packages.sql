-- Dev seed: course_package_manifest rows so the mobile offline flow resolves.
--
-- Problem (G3 / Story 4-1 / 6-2): GET /courses/{courseId}/packages/current
-- returned 404 for the seeded dev courses because no CoursePackageManifest was
-- ever persisted (the package generator uploaded files but never wrote a
-- manifest row). This seed inserts one current, immediately-effective manifest
-- per PUBLISHED course so `current` returns 200.
--
-- Idempotent: safe to run repeatedly. Uses the SAME version string the real
-- generator produces ("1.0.{dataVersionId}", see
-- PackageGenerationService.computeManifestVersion) so that if a real build later
-- runs for the same course+version it reuses this row instead of conflicting on
-- the unique (course_id, version) index.
--
-- Run: docker exec -i vsp_postgres psql -U vsp -d vsp < scripts/dev/seed_course_packages.sql

INSERT INTO course_package_manifest (
    id,
    course_id,
    data_version_id,
    version,
    package_size_bytes,
    checksum,
    effective_from,
    minimum_client_version,
    tiles_format,
    tiles_url,
    geo_json_url,
    conditions_url,
    metadata_url,
    generated_at,
    generated_by,
    accuracy_class,
    confidence
)
SELECT
    gen_random_uuid(),
    dv.course_id,
    dv.id,
    '1.0.' || dv.id                                                       AS version,
    0                                                                     AS package_size_bytes,
    encode(sha256((dv.course_id || ':1.0.' || dv.id)::bytea), 'hex')      AS checksum,
    now()                                                                 AS effective_from,
    '1.0.0'                                                               AS minimum_client_version,
    'PMTILES'                                                             AS tiles_format,
    'https://cdn.vnptgolf.vn/packages/' || dv.course_id || '/1.0.' || dv.id || '/tiles/tiles.pmtiles'        AS tiles_url,
    'https://cdn.vnptgolf.vn/packages/' || dv.course_id || '/1.0.' || dv.id || '/geometry/geometry.geojson'  AS geo_json_url,
    'https://cdn.vnptgolf.vn/packages/' || dv.course_id || '/1.0.' || dv.id || '/conditions/conditions.json' AS conditions_url,
    'https://cdn.vnptgolf.vn/packages/' || dv.course_id || '/1.0.' || dv.id || '/metadata/manifest.json'     AS metadata_url,
    now()                                                                 AS generated_at,
    'dev-seed'                                                            AS generated_by,
    'C_VERIFIED_SATELLITE'                                                AS accuracy_class,
    0.9                                                                   AS confidence
FROM data_versions dv
WHERE dv.status = 'PUBLISHED'
  AND NOT EXISTS (
        SELECT 1 FROM course_package_manifest m
        WHERE m.course_id = dv.course_id
          AND m.version = '1.0.' || dv.id
  );

-- Report what is now resolvable.
SELECT course_id, version, tiles_format, effective_from, generated_by
FROM course_package_manifest
ORDER BY course_id;
