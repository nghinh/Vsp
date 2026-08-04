-- V6__golfer_profiles.sql
-- Flyway migration: creates golfer_profiles table for golf-specific preferences.
-- Per PRD Section 8.1: golfer profile supports handicap, home club, distance unit,
--   dominant hand, target handicap, skill level, driver distance, swing speed, gender, birth year, country.
-- Per PRD Section 8.7: canonical unit storage is meters; display conversion is UI responsibility.
-- Per Story 2.3 AC-1: profile supports all required identity, handicap, home club, unit, hand, skill, target, distance fields.
-- Per Story 2.3 AC-2: canonical meters storage — unit changes do not corrupt canonical values.

CREATE TABLE golfer_profiles (
    id                      BIGSERIAL PRIMARY KEY,
    golfer_account_id      BIGINT NOT NULL UNIQUE REFERENCES golfer_accounts(id) ON DELETE CASCADE,

    -- Handicap
    handicap                DECIMAL(4,1),                          -- e.g. 12.5

    -- Home club
    home_club              VARCHAR(255),

    -- Distance unit preference (display only — canonical values always stored in meters)
    distance_unit          VARCHAR(10) NOT NULL DEFAULT 'METERS', -- METERS or YARDS

    -- Dominant hand
    dominant_hand          VARCHAR(10) NOT NULL DEFAULT 'RIGHT',  -- LEFT or RIGHT

    -- Skill level
    skill_level            VARCHAR(20) NOT NULL DEFAULT 'INTERMEDIATE', -- BEGINNER, INTERMEDIATE, ADVANCED, PRO

    -- Target score (average)
    target_score           INTEGER,                               -- e.g. 90

    -- Driver distance (canonical: meters)
    driver_distance        INTEGER,                               -- in meters

    -- Swing speed (mph)
    swing_speed            INTEGER,

    -- Identity extras
    gender                 VARCHAR(10),                           -- MALE, FEMALE, OTHER
    birth_year             INTEGER,
    country                 VARCHAR(100),
    image_url              VARCHAR(512),

    -- Timestamps
    created_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_distance_unit CHECK (distance_unit IN ('METERS', 'YARDS')),
    CONSTRAINT chk_dominant_hand CHECK (dominant_hand IN ('LEFT', 'RIGHT')),
    CONSTRAINT chk_skill_level CHECK (skill_level IN ('BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'PRO')),
    CONSTRAINT chk_gender CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER')),
    CONSTRAINT chk_handicap CHECK (handicap IS NULL OR (handicap >= -5 AND handicap <= 54)),
    CONSTRAINT chk_birth_year CHECK (birth_year IS NULL OR (birth_year >= 1900 AND birth_year <= 2010)),
    CONSTRAINT chk_driver_distance CHECK (driver_distance IS NULL OR driver_distance > 0),
    CONSTRAINT chk_swing_speed CHECK (swing_speed IS NULL OR (swing_speed >= 20 AND swing_speed <= 200))
);

-- Index for fast lookup by account
CREATE INDEX idx_golfer_profiles_account ON golfer_profiles (golfer_account_id);

COMMENT ON TABLE golfer_profiles IS 'Golfer golf-preference profile. Canonical distance values stored in meters; distance_unit field is display preference only.';
COMMENT ON COLUMN golfer_profiles.distance_unit IS 'Display preference only. All canonical distance values are stored in meters.';
COMMENT ON COLUMN golfer_profiles.driver_distance IS 'Canonical driver distance in meters. Display conversion: yards = meters * 1.09361.';
