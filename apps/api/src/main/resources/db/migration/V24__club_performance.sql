-- V24__club_performance.sql
-- Flyway migration: creates club_performance table for cached club performance statistics.
-- Per Story 11.1 Slice 1: cache computed stats, invalidate on new shot sync.
-- Per Story 11.1 AC-1: avg/median carry, total, variability, left/right, short/long, confidence.
-- Per Story 11.1 AC-2: sample size gate — recommendations locked until ≥30 shots.

CREATE TABLE club_performance (
    id                          BIGSERIAL PRIMARY KEY,

    -- Ownership (denormalised for faster queries)
    club_id                     BIGINT NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    golf_bag_id                 BIGINT NOT NULL REFERENCES golf_bags(id) ON DELETE CASCADE,
    golfer_account_id          BIGINT NOT NULL REFERENCES golfer_accounts(id) ON DELETE CASCADE,

    -- Sample quality
    sample_size                 INTEGER NOT NULL DEFAULT 0,
    sample_size_label           VARCHAR(20) NOT NULL,  -- INSUFFICIENT, LIMITED, MODERATE, ROBUST
    confidence_level             VARCHAR(20) NOT NULL,  -- INSUFFICIENT, LOW, MEDIUM, HIGH
    recommendations_locked       BOOLEAN NOT NULL DEFAULT true,

    -- Carry distance stats (meters)
    carry_avg                   DOUBLE PRECISION,
    carry_median                DOUBLE PRECISION,
    carry_std_dev               DOUBLE PRECISION,
    carry_min                   DOUBLE PRECISION,
    carry_max                   DOUBLE PRECISION,

    -- Total distance stats (meters)
    total_avg                   DOUBLE PRECISION,
    total_median                DOUBLE PRECISION,
    total_std_dev               DOUBLE PRECISION,
    total_min                   DOUBLE PRECISION,
    total_max                   DOUBLE PRECISION,

    -- Directional deviation stats (meters)
    left_right_avg              DOUBLE PRECISION,
    left_right_std_dev         DOUBLE PRECISION,
    short_long_avg              DOUBLE PRECISION,
    short_long_std_dev          DOUBLE PRECISION,

    -- Staleness tracking
    computed_at                 TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    based_on_shot_at            TIMESTAMPTZ,   -- most recent shot used in computation

    -- Timestamps
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_sample_size_label CHECK (sample_size_label IN ('INSUFFICIENT', 'LIMITED', 'MODERATE', 'ROBUST')),
    CONSTRAINT chk_confidence_level CHECK (confidence_level IN ('INSUFFICIENT', 'LOW', 'MEDIUM', 'HIGH'))
);

-- Indexes for fast lookup by club, bag, and golfer
CREATE INDEX idx_club_perf_club ON club_performance (club_id);
CREATE INDEX idx_club_perf_bag ON club_performance (golf_bag_id);
CREATE INDEX idx_club_perf_golfer ON club_performance (golfer_account_id);
CREATE INDEX idx_club_perf_based_on ON club_performance (based_on_shot_at);

-- Unique constraint: one stats record per club
CREATE UNIQUE INDEX idx_club_perf_club_unique ON club_performance (club_id);

COMMENT ON TABLE club_performance IS 'Cached club performance statistics. Computed on demand and invalidated when new shots are synced.';
COMMENT ON COLUMN club_performance.sample_size_label IS 'insufficient (<5), limited (5-9), moderate (10-29), robust (>=30)';
COMMENT ON COLUMN club_performance.confidence_level IS 'insufficient, low, medium, high';
COMMENT ON COLUMN club_performance.recommendations_locked IS 'True until >=30 shots accumulated. Does NOT suppress stats display.';
COMMENT ON COLUMN club_performance.left_right_avg IS 'Mean lateral deviation in meters (positive=right, negative=left)';
COMMENT ON COLUMN club_performance.short_long_avg IS 'Mean longitudinal deviation in meters (positive=long, negative=short)';
