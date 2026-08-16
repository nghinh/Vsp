-- Where the golf course stops and the neighbourhood begins.
--
-- A segmentation model looking at a satellite tile has no idea. Shown the
-- first hole at Long Biên it labelled the corrugated roofs of the houses next
-- door as water, because from above a blue-grey metal roof and a pond are the
-- same handful of pixels. Nothing about the model can fix that; it is being
-- asked a question the picture does not answer.
--
-- The course answers it. Every course has a cart path running the loop of it,
-- and OSM maps them — sixteen of them at Long Biên alone. Buffer that network,
-- union it with the features somebody already drew, and what comes out is the
-- ground a golfer can actually walk. Anything a model finds outside that is
-- not part of this golf course whatever it looks like.
--
-- Kept per course rather than per facility: Long Biên's three đường overlap
-- and interleave, and a boundary drawn around all of them at once would admit
-- the neighbouring nine's bunkers into every hole.

CREATE TABLE course_boundary (
    course_id       BIGINT PRIMARY KEY REFERENCES courses(id) ON DELETE CASCADE,

    -- WKT, like draft_geometry_features — the same reason: this schema keeps
    -- geometry as text and casts at the point of use.
    geometry        TEXT NOT NULL,

    -- What it was built from, so a boundary drawn before the cart paths were
    -- imported can be told apart from one drawn after.
    source          VARCHAR(50) NOT NULL,
    cart_path_count INTEGER NOT NULL DEFAULT 0,
    feature_count   INTEGER NOT NULL DEFAULT 0,
    area_hectares   NUMERIC(10, 2),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE course_boundary IS
    'The ground this course occupies. Traced geometry outside it is rejected — a model cannot tell a pond from a roof, and this is what tells it.';
COMMENT ON COLUMN course_boundary.source IS
    'cartpath+features where the cart path loop was available, features-only where it was not.';
