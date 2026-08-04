-- V8__clubs.sql
-- Flyway migration: creates clubs table for golf club inventory.
-- Per Story 2.4 AC-1: clubs can be created, edited, deleted with loft, carry, total, dispersion, shaft, useDate.
-- Per Story 2.4 AC-3: carryDistance stored to support minimum data threshold check.
-- Per PRD Section 9.1: Club listed as a core entity.
-- Per PRD Phase 2: dispersion stored (Phase 2 hook) but NOT used for recommendations in MVP.

CREATE TABLE clubs (
    id                      BIGSERIAL PRIMARY KEY,
    golf_bag_id             BIGINT NOT NULL REFERENCES golf_bags(id) ON DELETE CASCADE,

    -- Club type
    club_type               VARCHAR(20) NOT NULL,  -- DRIVER, WOOD, HYBRID, IRON, WEDGE, PUTTER

    -- Loft (degrees)
    loft                    DOUBLE PRECISION,

    -- Distances (canonical: meters)
    carry_distance          DOUBLE PRECISION,       -- distance in meters
    total_distance          DOUBLE PRECISION,       -- distance in meters

    -- Dispersion (degrees — Phase 2 scope per PRD Phase 2)
    dispersion              DOUBLE PRECISION,

    -- Shaft description
    shaft                   VARCHAR(100),

    -- When club was put into use
    use_date                DATE,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_club_type CHECK (club_type IN ('DRIVER', 'WOOD', 'HYBRID', 'IRON', 'WEDGE', 'PUTTER')),
    CONSTRAINT chk_loft CHECK (loft IS NULL OR (loft >= 0 AND loft <= 90)),
    CONSTRAINT chk_carry_distance CHECK (carry_distance IS NULL OR carry_distance > 0),
    CONSTRAINT chk_total_distance CHECK (total_distance IS NULL OR total_distance > 0),
    CONSTRAINT chk_dispersion CHECK (dispersion IS NULL OR dispersion >= 0)
);

-- Index for fast lookup by bag
CREATE INDEX idx_clubs_bag ON clubs (golf_bag_id);

COMMENT ON TABLE clubs IS 'Golf club inventory entry. Distances stored in canonical meters. Dispersion stored for Phase 2 use.';
COMMENT ON COLUMN clubs.carry_distance IS 'Canonical carry distance in meters. Display conversion: yards = meters * 1.09361.';
COMMENT ON COLUMN clubs.total_distance IS 'Canonical total distance in meters (includes roll). Display conversion: yards = meters * 1.09361.';
COMMENT ON COLUMN clubs.dispersion IS 'Dispersion in degrees. Phase 2 scope — stored but not used in MVP recommendations.';
