-- V7__golf_bags.sql
-- Flyway migration: creates golf_bags table for golfer equipment management.
-- Per Story 2.4 AC-1: bags can be created, edited, deleted.
-- Per Story 2.4 AC-2: exactly one bag is active at a time (enforced at service layer).
-- Per PRD Section 9.1: GolfBag listed as a core entity.

CREATE TABLE golf_bags (
    id                      BIGSERIAL PRIMARY KEY,
    golfer_account_id      BIGINT NOT NULL REFERENCES golfer_accounts(id) ON DELETE CASCADE,

    -- Bag identity
    name                    VARCHAR(255) NOT NULL DEFAULT 'My Bag',
    is_active               BOOLEAN NOT NULL DEFAULT FALSE,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT chk_bag_name_nonempty CHECK (LENGTH(TRIM(name)) > 0)
);

-- Index for fast lookup by account + active flag
CREATE INDEX idx_golf_bags_account ON golf_bags (golfer_account_id);
CREATE INDEX idx_golf_bags_account_active ON golf_bags (golfer_account_id, is_active) WHERE is_active = TRUE;

COMMENT ON TABLE golf_bags IS 'Golfer golf bag. Exactly one bag is active per golfer at any time — enforced at service layer.';
COMMENT ON COLUMN golf_bags.is_active IS 'Only one bag should be active per golfer at a time. Enforced by BagService.setActiveBag().';
