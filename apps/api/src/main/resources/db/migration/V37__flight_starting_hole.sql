-- Which hole a flight starts on.
--
-- flights.starting_tee is FRONT or BACK, which describes a two-wave start: one
-- group off the 1st, another off the 10th. The club does not run that. Its
-- programme says "06h30: ShotGuns (11 FLight)" and the flight sheet says
-- "Start Hố 1" — eleven groups going out at the same minute from eleven
-- different tees. FRONT/BACK cannot say which one, so a flight starting on the
-- 7th was recorded as "FRONT" along with the flight on the 1st, and the
-- starter's sheet could not be reproduced from the data.
--
-- Nullable: a two-wave event still has nothing to put here, and starting_tee
-- keeps carrying that case.

ALTER TABLE flights
    ADD COLUMN starting_hole INTEGER;

COMMENT ON COLUMN flights.starting_hole IS
    'Hole this flight tees off from in a shotgun start. Null for a two-wave '
    'start, where starting_tee (FRONT/BACK) is the whole answer.';

-- starting_tee stays NOT NULL and stays meaningful: it is derivable from the
-- hole, and existing rows already have it.
