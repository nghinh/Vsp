-- V19: Search Infrastructure — Favorites, Recent, and Course Search
-- Per Story 3.2 SD-BACK-1: user-scoped favorites/recent + course search repository
-- Requires: V16__facilities_courses_holes.sql (courses table), V18__course_condition_and_versioning.sql (data_versions)

-- FavoriteCourse: user favorited course association
CREATE TABLE favorite_courses (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_favorite_user_course UNIQUE (user_id, course_id)
);
CREATE INDEX idx_favorite_user ON favorite_courses(user_id);
CREATE INDEX idx_favorite_course ON favorite_courses(course_id);

-- RecentCourse: user recently viewed course (capped at 10 per user)
CREATE TABLE recent_courses (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    course_id BIGINT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_recent_user_course UNIQUE (user_id, course_id)
);
CREATE INDEX idx_recent_user ON recent_courses(user_id);
CREATE INDEX idx_recent_viewed ON recent_courses(user_id, viewed_at DESC);

COMMENT ON TABLE favorite_courses IS 'User favorited course associations. Per Story 3.2 AC-1.';
COMMENT ON TABLE recent_courses IS 'User recently viewed courses, trimmed to 10 per user. Per Story 3.2 AC-1.';
