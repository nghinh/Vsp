-- Course alerts table for course operation alerts
-- Per Story 8.6 Slice 1: CourseAlert domain model and persistence
-- AC-1: targeting via facility/course/hole/flight/group fields
-- AC-3: delivery, expiry, acknowledgment tracking; audit via data quality fields

CREATE TABLE course_alerts (
    id BIGSERIAL PRIMARY KEY,

    -- Targeting (AC-1: at least one target required at service layer)
    facility_id UUID,
    course_id   UUID,
    hole_id     UUID,
    flight_id   UUID,
    group_id    UUID,

    -- Alert classification (AC-2: visual distinction)
    alert_type VARCHAR(20) NOT NULL DEFAULT 'SAFETY',

    -- Content
    title    VARCHAR(255) NOT NULL,
    body     TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 0,

    -- Timing (AC-3)
    effective_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMP WITH TIME ZONE,

    -- Delivery tracking (AC-3)
    delivery_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',

    -- Acknowledgment (AC-3)
    acknowledgment_required BOOLEAN NOT NULL DEFAULT FALSE,
    acknowledged_at         TIMESTAMP,
    acknowledged_by         VARCHAR(255),

    -- Audit & versioning
    created_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by         VARCHAR(255) NOT NULL,
    published_version   INTEGER NOT NULL DEFAULT 1,

    -- Data quality fields (Architecture §9.3)
    source              VARCHAR(255),
    license             VARCHAR(100),
    accuracy_class      VARCHAR(10),
    confidence          DECIMAL(5,2) DEFAULT 0.00,
    verification_status VARCHAR(20),
    version             INTEGER NOT NULL DEFAULT 1,

    -- Constraints
    CONSTRAINT chk_alert_type CHECK (alert_type IN ('SAFETY', 'PROMOTION')),
    CONSTRAINT chk_delivery_status CHECK (delivery_status IN ('PENDING', 'DELIVERED', 'FAILED', 'EXPIRED'))
);

-- Indexes for targeting queries
CREATE INDEX idx_course_alert_facility   ON course_alerts(facility_id) WHERE facility_id IS NOT NULL;
CREATE INDEX idx_course_alert_course     ON course_alerts(course_id)   WHERE course_id   IS NOT NULL;
CREATE INDEX idx_course_alert_hole       ON course_alerts(hole_id)     WHERE hole_id     IS NOT NULL;
CREATE INDEX idx_course_alert_flight     ON course_alerts(flight_id)   WHERE flight_id   IS NOT NULL;
CREATE INDEX idx_course_alert_group      ON course_alerts(group_id)    WHERE group_id    IS NOT NULL;

-- Indexes for alert delivery and timing
CREATE INDEX idx_course_alert_type     ON course_alerts(alert_type);
CREATE INDEX idx_course_alert_delivery ON course_alerts(delivery_status);
CREATE INDEX idx_course_alert_effective ON course_alerts(effective_at);
CREATE INDEX idx_course_alert_expires  ON course_alerts(expires_at) WHERE expires_at IS NOT NULL;

-- Index for acknowledgment queries
CREATE INDEX idx_course_alert_ack_pending ON course_alerts(acknowledgment_required, acknowledged_at)
    WHERE acknowledgment_required = true AND acknowledged_at IS NULL;
