-- Course corrections table for golfer-submitted course data corrections
-- Per Story 9.2: Correction Queue Review (Slice A — Backend Core)
-- AC-1: queue with course/hole/type/status/confidence/date filters
-- AC-2: reporter evidence, location, map context, official data
-- AC-3: reviewer can approve/reject/request info/convert to draft

CREATE TABLE course_corrections (
    id BIGSERIAL PRIMARY KEY,

    -- Core identification
    course_id BIGINT NOT NULL,
    hole_id    BIGINT,
    reporter_id BIGINT NOT NULL,

    -- Reporter evidence (AC-2)
    reporter_note        TEXT,
    reporter_evidence_url VARCHAR(1024),
    reporter_gps_location geometry(Point, 4326),

    -- Classification
    correction_type VARCHAR(30) NOT NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    confidence        DECIMAL(5,2),

    -- Submission
    submitted_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Review fields
    reviewed_at  TIMESTAMP,
    reviewed_by   BIGINT,
    review_note   TEXT,
    resolution    TEXT,

    -- Data quality metadata (Architecture §9.3)
    source              VARCHAR(255),
    license             VARCHAR(100),
    accuracy_class      VARCHAR(10),
    verification_status VARCHAR(20),
    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    last_verified_at    TIMESTAMP,
    effective_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    expiry_date         DATE,
    publisher           VARCHAR(255) NOT NULL,
    version             INTEGER NOT NULL DEFAULT 1,

    -- Constraints
    CONSTRAINT chk_correction_type CHECK (correction_type IN (
        'GEOMETRY', 'PIN_POSITION', 'BUNKER', 'WATER', 'OB',
        'CART_PATH', 'LANDMARK', 'COURSE_CONDITION', 'GREEN_SPEED', 'OTHER'
    )),
    CONSTRAINT chk_correction_status CHECK (status IN (
        'PENDING', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'INFO_REQUESTED', 'CONVERTED_TO_DRAFT'
    ))
);

-- Indexes for queue filtering (AC-1)
CREATE INDEX idx_correction_course    ON course_corrections(course_id);
CREATE INDEX idx_correction_hole       ON course_corrections(hole_id) WHERE hole_id IS NOT NULL;
CREATE INDEX idx_correction_reporter  ON course_corrections(reporter_id);
CREATE INDEX idx_correction_status    ON course_corrections(status);
CREATE INDEX idx_correction_type      ON course_corrections(correction_type);
CREATE INDEX idx_correction_submitted ON course_corrections(submitted_at);
CREATE INDEX idx_correction_confidence ON course_corrections(confidence) WHERE confidence IS NOT NULL;
