-- V16: Facilities, Courses, and Holes — Core Hierarchy
-- Per Story 3.1 AC-1: PostGIS schema represents facilities, courses, holes (core hierarchy)
-- Per Architecture §7.1, §7.2: PostgreSQL/PostGIS canonical source, SRID 4326
-- Requires: V15__course_geometry_foundation.sql (enums, metadata table, validity trigger)

-- GolfFacility: top-level anchor for a golf property
CREATE TABLE golf_facilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    address VARCHAR(500),
    phone VARCHAR(50),
    website VARCHAR(255),
    -- Facility centroid as WKT POINT in SRID 4326 (varchar for portability)
    location VARCHAR,
    -- One-to-one FK to shared data quality metadata
    data_quality_metadata_id BIGINT REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- GIST spatial index on location for PostGIS ST_DWithin queries
-- Per Architecture §7.2: GIST indexes on spatial columns
CREATE INDEX idx_golf_facilities_location ON golf_facilities USING GIST (ST_GeomFromWKB(location::bytea));
-- Note: since location is VARCHAR, cast to geometry using ST_GeomFromWKT
-- In production with hibernate-spatial, use: CREATE INDEX idx_golf_facilities_location ON golf_facilities USING GIST (location);

CREATE INDEX idx_golf_facilities_name ON golf_facilities(name);

-- Course: a playable golf course within a GolfFacility
CREATE TABLE courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES golf_facilities(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    holes_count INTEGER,
    par_total INTEGER,
    -- Course location as WKT POINT or POLYGON in SRID 4326
    location VARCHAR,
    -- One-to-one FK to shared data quality metadata
    data_quality_metadata_id BIGINT REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_courses_facility ON courses(facility_id);
CREATE INDEX idx_courses_name ON courses(name);
-- Spatial index on location for ST_DWithin proximity queries
CREATE INDEX idx_courses_location ON courses USING GIST (ST_GeomFromWKB(location::bytea));

-- Hole: a single hole on a course
CREATE TABLE holes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    hole_number INTEGER NOT NULL,
    par INTEGER NOT NULL CHECK (par BETWEEN 1 AND 9),
    -- Teeing ground location as WKT POINT in SRID 4326
    teeing_ground_location VARCHAR,
    -- Putting green center location as WKT POINT in SRID 4326
    green_location VARCHAR,
    -- Playing length tee-to-green in meters
    playing_length_meters DECIMAL(8,2),
    -- One-to-one FK to shared data quality metadata
    data_quality_metadata_id BIGINT REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Enforce hole_number uniqueness per course
    CONSTRAINT uq_hole_course_number UNIQUE (course_id, hole_number)
);

CREATE INDEX idx_holes_course ON holes(course_id);
CREATE INDEX idx_holes_number ON holes(hole_number);
-- Spatial index on green_location for golfer positioning queries
CREATE INDEX idx_holes_green_location ON holes USING GIST (ST_GeomFromWKB(green_location::bytea));
-- Spatial index on teeing_ground_location for tee selection queries
CREATE INDEX idx_holes_tee_location ON holes USING GIST (ST_GeomFromWKB(teeing_ground_location::bytea));

-- Geometry validity enforcement via trigger (defined in V15)
-- Applied to all geometry columns created in this migration
CREATE TRIGGER trg_facilities_geometry_validity
    BEFORE INSERT OR UPDATE ON golf_facilities
    FOR EACH ROW
    EXECUTE FUNCTION geometry_validity_trigger();

CREATE TRIGGER trg_courses_geometry_validity
    BEFORE INSERT OR UPDATE ON courses
    FOR EACH ROW
    EXECUTE FUNCTION geometry_validity_trigger();

CREATE TRIGGER trg_holes_teeing_ground_validity
    BEFORE INSERT OR UPDATE ON holes
    FOR EACH ROW
    EXECUTE FUNCTION geometry_validity_trigger();

CREATE TRIGGER trg_holes_green_validity
    BEFORE INSERT OR UPDATE ON holes
    FOR EACH ROW
    EXECUTE FUNCTION geometry_validity_trigger();
