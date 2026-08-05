# Course digitisation

839 of the 900 holes have no real geometry: OpenStreetMap covers only 61 (the
rest of Vietnam's courses are not mapped hole-by-hole). Those holes still carry
seeded coordinates, so their fairways are derived and labelled unverified.

Three pipelines feed the same tables, in this order:

1. [`osm/`](osm/) — **automatic**, and the source of everything the database
   currently knows: facility coordinates, 61 real holes, and the OSM greens,
   bunkers and water hazards around them. Reproducible from a committed
   snapshot and idempotent.
2. [`satellite/`](satellite/) — **automatic**, free Sentinel-2 imagery, water
   hazards only. Adds 40 ponds nobody had mapped. It finds 40% of the hazards
   OSM already knows about, and it cannot see bunkers at all — read that
   directory's README before quoting either number.
3. this directory — **manual**, for the 839 holes neither of them can supply.

## 1. `holes_todo.geojson` — the work list

One feature per outstanding hole: a bounding box around the tee→green line with
80 m of margin, plus the hole's identity (`db_hole_id`, course, hole number, par,
length). Open it in JOSM or QGIS, zoom to a box, and trace the real features over
imagery.

Regenerate it after any import so finished holes drop off:

```sh
python3 make_holes_todo.py
```

## 2. `import_digitized.py` — the way back in

```sh
python3 import_digitized.py traced.geojson \
    --publisher "Acme Survey" --license "ODbL-1.0"      # dry run
python3 import_digitized.py traced.geojson \
    --publisher "Acme Survey" --license "ODbL-1.0" --apply
```

Each traced feature needs `db_hole_id`, `layer` (green | fairway | bunker |
water | ob) and `source` (which imagery). The script refuses the whole batch if
any feature fails validation, and writes in one transaction — a half-imported
course is worse than an empty one, because it looks finished.

Imports land as `PENDING_REVIEW` with `confidence 0.80`. Nothing becomes
`VERIFIED` without a human saying so.

## Imagery licensing — read before tracing

**Do not trace Google Maps or Google Earth.** Their terms forbid it and the
derived geometry is then encumbered; this is why OSM bans Google sources
outright. Use one of:

| Source | Status |
|---|---|
| Bing Aerial | licensed for tracing |
| Esri World Imagery | licensed for tracing |
| Maxar | under contract |
| Course-supplied aerial/drone | cleanest, and courses usually cooperate |

The `source`, `publisher` and `license` columns record this per feature, so an
audit can always answer where a polygon came from.

## What this pipeline cannot supply

Pin positions and green speed change daily. They belong to the course's own
operations, entered through the admin portal — no amount of imagery tracing
produces them.
