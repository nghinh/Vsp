-- Search that does not depend on the golfer typing the diacritics.
--
-- Course search matched with LOWER(name) LIKE '%query%', so "Long Biên" found
-- the club and "Long Bien" found nothing. On a phone most people type without
-- diacritics, or get half of them, which is why the same club appeared and
-- disappeared depending on how it was typed.
--
-- unaccent folds them, Vietnamese included — it maps đ to d, which the plain
-- ASCII fold in most libraries does not:
--
--   unaccent('Long Biên')  → 'Long Bien'
--   unaccent('Đường A')    → 'Duong A'
--   unaccent('Móng Cái')   → 'Mong Cai'

CREATE EXTENSION IF NOT EXISTS unaccent;
