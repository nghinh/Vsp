-- Add FK from privacy_requests to rounds (rounds now exists via V13)
-- Per Story 2.5 AC-3: target_round_id references rounds(id)
ALTER TABLE privacy_requests
    ADD CONSTRAINT fk_privacy_requests_target_round
    FOREIGN KEY (target_round_id) REFERENCES rounds(id);

CREATE INDEX idx_privacy_requests_target_round ON privacy_requests(target_round_id);
