# Water hazards from Sentinel-2

Open satellite imagery can fill part of the missing water-hazard layer. Not all
of it, and not the bunker layer at all. This directory holds the pipeline and
the measurements that say how far it goes.

```sh
python3 -m venv venv && ./venv/bin/pip install -r requirements.txt
./venv/bin/python detect_water_ndwi.py --validate        # score against OSM, write nothing
./venv/bin/python detect_water_ndwi.py --preview /tmp/pv # dry run + pictures
./venv/bin/python detect_water_ndwi.py --apply           # commit
```

Run `../osm/build_from_osm.py --apply` first: this pipeline attaches ponds to
the real hole lines that one produces, and clips to the course outline it
stages.

## The verdict up front

**Viable, partially, and only where the holes are real.** 40 water hazards
across 7 courses, none of which existed before. Against the 10 hazards OSM has
mapped by hand on these same courses, the detector finds 4 — a 40% recall that
is worth understanding rather than reporting.

**Bunkers are not viable and were not attempted.** A golf bunker is 5-15 m
across. One Sentinel-2 pixel is 10 m, and it is a *mixture* of sand and the
turf around it — the sand never gets a pixel to itself, so its spectrum never
appears cleanly. There is no threshold, index, or post-processing that recovers
a shape from that. Bunkers need sub-metre imagery, which means a commercial
provider or a licensed basemap; the manual tracing route in `../README.md` is
the honest answer for them today.

## Why MNDWI and not NDWI

The brief suggested NDWI, `(green - NIR) / (green + NIR)`. Measured at the one
pond on these courses that is unambiguously open water:

| index | value | verdict |
|---|---|---|
| NDWI `(green - NIR)/(green + NIR)` | 0.10 | barely above the grass around it |
| MNDWI `(green - SWIR)/(green + SWIR)` | 0.58 | unmistakable |

Vietnamese course ponds are shallow, turbid and frequently algal. Suspended
sediment and algae both lift near-infrared reflectance, which is exactly the
band NDWI relies on being dark — so NDWI collapses towards the fairway value.
SWIR (B11, 1.6 µm) is absorbed by liquid water regardless of what is floating in
it, so MNDWI keeps its separation. B11 is a 20 m band resampled onto the 10 m
grid; the cost is a blurrier outline, not a missed pond. Switching indices took
recall from 20% to 40% on the same imagery.

## Where the other 60% went

Every OSM-mapped hazard the detector missed was checked by hand against the
pixels. None of them is a tuning failure:

| hazard | area | MNDWI | why it was missed |
|---|---|---|---|
| Kings Island | 2410 m² | -0.09 | no water signal on any date — dry or fully vegetated |
| Twin Doves | 627 m² | -0.06 | 6 pixels, all mixed with the bank |
| Twin Doves | 1008 m² | -0.11 | same |
| Twin Doves | 1460 m² | -0.16 | same |

Below roughly 2000 m² a hazard is a handful of mixed pixels and its spectrum is
mostly bank, not water. That is the resolution floor, and lowering the threshold
to reach past it buys false positives, not hazards.

The reverse also holds: a detection with no OSM counterpart is not automatically
wrong. OSM's water coverage on these courses is patchy, and most of the 40
written rows are ponds nobody has mapped. That is the value here — but it is
also why not one of them claims to be verified.

## The filters, and why each exists

| filter | reason |
|---|---|
| 2 of 3 clear dates | one date cannot tell a pond from a flooded field, a rain puddle, or a cloud shadow the mask missed |
| same MGRS tile | so the three dates share a pixel grid and the vote is per-pixel, not per-approximate-location |
| SCL cloud/shadow mask, AOI cloud < 2% | a scene 8% cloudy nationally can be solid cloud over the one course that matters |
| inside the OSM course outline | "within 120 m of a hole" is not "on the course" — in the delta a fairway runs alongside fish farms, and MNDWI cannot tell a hazard from a shrimp pond. The outline can. 31 of 88 detections were dropped here |
| 200 m² - 150000 m² | below is noise, above is a river or the reservoir the course sits on |
| within 120 m of a hole line | the row needs a hole to attach to |
| not intersecting an OSM hazard | never shadow a hand-mapped polygon with a 10 m-pixel guess at the same pond |

## Provenance

Every row: `accuracy_class = D_UNVERIFIED_COMMUNITY`,
`verification_status = PENDING_REVIEW`, `confidence = 0.25`,
`source = sentinel2:<scene id>`,
`publisher = 'Contains modified Copernicus Sentinel data'`,
`license = 'Copernicus Sentinel Data Legal Notice'`.

Copernicus Sentinel data is free to use, redistribute and adapt under the Legal
Notice on the use of Copernicus Sentinel Data and Service Information
(Commission Delegated Regulation (EU) No 1159/2013). The one obligation it
carries is attribution — "Contains modified Copernicus Sentinel data \<year\>"
for a derived product — which is why the publisher column reads the way it does
rather than naming a vendor. The AWS Open Data mirror adds no terms of its own.

## Reproducibility

Unlike the OSM pipeline next door, this one has no committed snapshot: a
Sentinel-2 archive is terabytes and cannot be checked into a git repository.
What it has instead is determinism given a date window — `--start` / `--end`
pin the search, the scene choice is the lowest cloud cover in that window, and
the run records the scene id and every contributing date in
`sat_water_staging`. Re-running with the same window against the same archive
selects the same scenes and produces the same polygons. Re-running with a
different window will not, and should not.

Idempotent in the same sense as the OSM pipeline: `sentinel2:` rows that are
not `VERIFIED` are deleted and rebuilt each run; a row a human has verified is
kept, counted, and never duplicated.

## Reviewing the output

```sh
./venv/bin/pip install pillow
./venv/bin/python detect_water_ndwi.py --preview /tmp/pv
```

One PNG per course: true-colour Sentinel-2, the course outline in yellow, the
real hole lines in blue, detections in red where they would be written and grey
where a filter throws them out. Forty PENDING_REVIEW polygons is a small enough
pile that a human can look at all of them, and this is how.
