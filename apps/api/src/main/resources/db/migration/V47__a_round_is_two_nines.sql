-- A round is two nines, and rounds could only name one course.
--
-- Long Biên is đường A, B and C, nine holes each. A golfer starting an
-- eighteen there picks two of them — the club prints the card that way and the
-- app the operator photographed asks for exactly that: "Đường đi" and "Đường
-- về".
--
-- rounds held one course_id, so a round at Long Biên was bound to nine holes
-- and played eighteen. Holes 10 to 18 belonged to no course at all:
--
--   the hole map said "hố này chưa có bản đồ khảo sát" for every one of them,
--   because there is no hole 10 on a nine-hole course;
--
--   hole advice answered 404, which the sheet showed as "không tải được
--   thông tin hố này";
--
--   and the pars, stroke indexes and yardages for the back nine were simply
--   absent, on a club whose card this project had already loaded in full.
--
-- back_nine_course_id is the second half. course_id keeps its meaning as the
-- first, so every round already recorded stays exactly what it was, and a
-- round on a single eighteen-hole course leaves the new column null rather
-- than repeating itself.
--
-- The mapping this enables is the point: hole 10 of the round is hole 1 of the
-- back nine, and that is what the map, the scorecard and the advice all have
-- to ask for.

ALTER TABLE rounds
    ADD COLUMN IF NOT EXISTS back_nine_course_id bigint;

ALTER TABLE rounds
    ADD CONSTRAINT rounds_back_nine_course_id_fkey
    FOREIGN KEY (back_nine_course_id) REFERENCES courses(id);

COMMENT ON COLUMN rounds.course_id IS
    'The first nine, or the whole course where the round is one eighteen-hole layout.';
COMMENT ON COLUMN rounds.back_nine_course_id IS
    'The second nine, where the round is composed of two. Null for a round on a single course.';
