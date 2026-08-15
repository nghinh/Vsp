-- The golfer's own book of caddies.
--
-- A detail no foreign golf app understands: Vietnamese courses require a
-- caddie, and the printed cards say so — FLC's card makes one per golfer a
-- local rule, and the cards this project photographs come back with caddie
-- numbers written in the corner and a "Caddies Rating" box the clubs
-- themselves print. Golfers remember the good ones and ask for them by number
-- at the desk. That memory currently lives nowhere.
--
-- One row per (golfer, club, caddie number). Private per golfer: this is a
-- personal notebook, not a public review site — a review site invites
-- disputes with people whose livelihood is tips, which is not a thing this
-- app should host.

CREATE TABLE caddie_notes (
    id                 BIGSERIAL PRIMARY KEY,
    golfer_account_id  BIGINT NOT NULL REFERENCES golfer_accounts(id) ON DELETE CASCADE,
    facility_id        BIGINT NOT NULL REFERENCES golf_facilities(id) ON DELETE CASCADE,
    caddie_number      VARCHAR(20) NOT NULL,
    name               VARCHAR(100),
    rating             INT CHECK (rating BETWEEN 1 AND 5),
    note               TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (golfer_account_id, facility_id, caddie_number)
);

CREATE INDEX idx_caddie_notes_owner ON caddie_notes (golfer_account_id, facility_id);
