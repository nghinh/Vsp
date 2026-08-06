-- V17: Golf Feature Geometry Tables
-- Per Story 3.1 GEO-3: all spatial feature tables with SRID 4326, validity constraints, GIST indexes.

-- Tee boxes (teeing ground areas)
CREATE TABLE tee_boxes (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    tee_set_id BIGINT,
    location GEOMETRY(POLYGON, 4326),
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tee_boxes_hole ON tee_boxes(hole_id);
CREATE INDEX idx_tee_boxes_location ON tee_boxes USING GIST(location);

-- Fairway segments
CREATE TABLE fairway_segments (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(GEOMETRY, 4326), -- POLYGON or LINESTRING
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_fairway_segments_hole ON fairway_segments(hole_id);
CREATE INDEX idx_fairway_segments_location ON fairway_segments USING GIST(location);

-- Greens
CREATE TABLE greens (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(POLYGON, 4326),
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_greens_hole ON greens(hole_id);
CREATE INDEX idx_greens_location ON greens USING GIST(location);

-- Bunkers (sand traps)
CREATE TABLE bunkers (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(POLYGON, 4326),
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_bunkers_hole ON bunkers(hole_id);
CREATE INDEX idx_bunkers_location ON bunkers USING GIST(location);

-- Water hazards
CREATE TABLE water_hazards (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(GEOMETRY, 4326), -- POLYGON or LINESTRING
    hazard_type VARCHAR(50),
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_water_hazards_hole ON water_hazards(hole_id);
CREATE INDEX idx_water_hazards_location ON water_hazards USING GIST(location);

-- Penalty areas
CREATE TABLE penalty_areas (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(POLYGON, 4326),
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_penalty_areas_hole ON penalty_areas(hole_id);
CREATE INDEX idx_penalty_areas_location ON penalty_areas USING GIST(location);

-- Out of bounds
CREATE TABLE out_of_bounds (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(GEOMETRY, 4326), -- LINESTRING or POLYGON boundary
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_out_of_bounds_hole ON out_of_bounds(hole_id);
CREATE INDEX idx_out_of_bounds_location ON out_of_bounds USING GIST(location);

-- Cart paths
CREATE TABLE cart_paths (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(LINESTRING, 4326),
    path_type VARCHAR(50),
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_cart_paths_hole ON cart_paths(hole_id);
CREATE INDEX idx_cart_paths_location ON cart_paths USING GIST(location);

-- Landmarks
CREATE TABLE landmarks (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(POINT, 4326),
    landmark_type VARCHAR(50),
    name VARCHAR(255),
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_landmarks_hole ON landmarks(hole_id);
CREATE INDEX idx_landmarks_location ON landmarks USING GIST(location);

-- Tee sets (named tee groupings: Black, White, Gold, etc.)
CREATE TABLE tee_sets (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    total_par INTEGER,
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tee_sets_course ON tee_sets(course_id);

ALTER TABLE tee_boxes
    ADD CONSTRAINT fk_tee_boxes_tee_set
    FOREIGN KEY (tee_set_id) REFERENCES tee_sets(id) ON DELETE SET NULL;

-- Pin positions with effective/expiry scheduling
CREATE TABLE pin_positions (
    id BIGSERIAL PRIMARY KEY,
    hole_id BIGINT NOT NULL REFERENCES holes(id) ON DELETE CASCADE,
    location GEOMETRY(POINT, 4326),
    pin_position_type VARCHAR(50),
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date DATE,
    data_quality_id BIGINT NOT NULL REFERENCES data_quality_metadata(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_pin_positions_hole ON pin_positions(hole_id);
CREATE INDEX idx_pin_positions_location ON pin_positions USING GIST(location);
CREATE INDEX idx_pin_positions_effective ON pin_positions(effective_date);
