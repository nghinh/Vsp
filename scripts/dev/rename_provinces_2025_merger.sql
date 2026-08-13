-- Bring facility addresses up to the 2025 provincial merger.
--
-- WHAT HAPPENED
--
--   On 12 June 2025 Vietnam went from 63 provinces to 34. Twenty-nine of the
--   old ones stopped existing: Quảng Bình was merged into Quảng Trị, Bắc Giang
--   into Bắc Ninh, Vĩnh Phúc and Hòa Bình into Phú Thọ, Bà Rịa – Vũng Tàu and
--   Bình Dương into Thành phố Hồ Chí Minh, and so on.
--
--   The nationwide seed was written against the old map, so thirty-five of the
--   seventy-two facilities carry a province that is no longer on it. This is
--   not a guess to be corrected later like the invented hole geometry — the
--   mapping is published, one old name to exactly one new one, and nothing
--   about a golf course moved.
--
-- WHY THE OLD NAME STAYS IN THE STRING
--
--   Course search matches facility name, course name and address, so replacing
--   "Quảng Bình" outright means a golfer who searches the name they have used
--   all their life finds nothing. The clubs themselves are still commonly
--   listed under the old province, and a golfer standing in Đồng Hới does not
--   think of themselves as being in Quảng Trị. Both names are kept:
--
--     Đồng Hới, Quảng Bình  →  Đồng Hới, Quảng Trị (Quảng Bình cũ)
--
--   Same reasoning as keeping "(Sông Giá)" on Sono Belle Hải Phòng.
--
-- WHAT IT DOES NOT DO
--
--   It does not touch coordinates. A merger renames the province; it does not
--   move the club, and the facilities with missing or kilometre-scale
--   coordinates still have them.
--
--   It is idempotent by construction: a row whose address already ends in the
--   new name matches neither UPDATE, so re-running it changes nothing.
--
-- USAGE
--
--   Run inside a transaction you can roll back after reading the count:
--
--     ssh ubuntu-docker "cd ~/vsp && docker compose exec -T vsp-postgres \
--       psql -U vsp -d vsp -v ON_ERROR_STOP=1" < scripts/dev/rename_provinces_2025_merger.sql
--
--   The final SELECT prints how many facilities still carry a dead province.
--   It must be 0.
--
-- Source: https://vi.wikipedia.org/wiki/Sáp_nhập_tỉnh,_thành_Việt_Nam_2025

\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE prov_merge(old_name text PRIMARY KEY, new_name text) ON COMMIT DROP;

-- Only the fifteen that appear in golf_facilities. The merger touched more,
-- and listing ones no facility uses would be untested code.
INSERT INTO prov_merge VALUES
 ('Bắc Giang',         'Bắc Ninh'),
 ('Bà Rịa - Vũng Tàu', 'TP. Hồ Chí Minh'),
 ('Bình Dương',        'TP. Hồ Chí Minh'),
 ('Bình Thuận',        'Lâm Đồng'),
 ('Hải Dương',         'Hải Phòng'),
 ('Hà Nam',            'Ninh Bình'),
 ('Hòa Bình',          'Phú Thọ'),
 ('Kiên Giang',        'An Giang'),
 ('Long An',           'Tây Ninh'),
 ('Ninh Thuận',        'Khánh Hòa'),
 ('Quảng Bình',        'Quảng Trị'),
 ('Quảng Nam',         'Đà Nẵng'),
 ('Thừa Thiên Huế',    'Huế'),
 ('Vĩnh Phúc',         'Phú Thọ'),
 ('Yên Bái',           'Lào Cai');

-- Two rows carry the province and nothing else — Royal Island ("Bình Dương")
-- and Royal Long An ("Long An") — so they have no comma to anchor on and the
-- suffix rewrite below misses them.
UPDATE golf_facilities f
SET address = m.new_name || ' (' || m.old_name || ' cũ)',
    updated_at = now()
FROM prov_merge m
WHERE btrim(f.address) = m.old_name;

UPDATE golf_facilities f
SET address = regexp_replace(
        f.address,
        ', ' || m.old_name || '$',
        ', ' || m.new_name || ' (' || m.old_name || ' cũ)'),
    updated_at = now()
FROM prov_merge m
WHERE f.address LIKE '%, ' || m.old_name;

SELECT count(*) AS facilities_still_on_a_dead_province
FROM golf_facilities f
JOIN prov_merge m ON btrim(split_part(f.address, ',', -1)) = m.old_name;

COMMIT;
