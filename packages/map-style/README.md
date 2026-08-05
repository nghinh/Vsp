# Map Style Package — Vietnam Smart Golf Platform

## Status: the mobile style lives in Dart, not here

The MapLibre style the app actually loads is built in code:

- `apps/mobile/lib/features/hole_map/domain/course_map_style_builder.dart` —
  the vector course map
- `apps/mobile/lib/features/basemap/domain/satellite_style_builder.dart` —
  the satellite + measuring basemap

The `style.json` that used to sit here was removed because it could not work,
in three separate ways, and leaving it invited the same bug back:

1. **It could not load.** The map asked for it as
   `packages/map-style/style.json`, which is Flutter's "asset owned by another
   package" form. `map-style` is not a Dart package (no `pubspec.yaml`, and a
   hyphen is not legal in a Dart package name), it was not a dependency of the
   app, and it was not in the asset bundle. The course-map mode therefore never
   rendered.
2. **Its data source did not exist.** Its only geometry source was the vector
   tile endpoint `https://tiles.vsp.vn/courses/{z}/{x}/{y}.mvt`. The app already
   ships hole geometry inside the downloaded course package, which is what a
   golfer has on a course with no signal, so the Dart style reads that instead.
3. **Its labels needed a font server.** Symbol layers require a `glyphs`
   endpoint (it pointed at `fonts.openmaptiles.org`). Nobody should wait on a
   CDN to see the green, so there are no symbol layers now — labels are Flutter
   widgets drawn over the map.

## What still belongs here

Sprites and font stacks, if the app ever ships them as real bundled assets from
a proper Dart package. Until then this directory is documentation only: the
palette, layer names and draw order are defined in the two builders above and
covered by their unit tests.

## Style layers (MVP)

- Tee boxes, fairway, rough, green, bunker, water, penalty area, OB — fill plus
  outline, from the course package's GeoJSON
- Cart paths — dashed line
- Pin, golfer position, targets, landmarks — circle layers (no glyphs needed)
- GPS accuracy disc and 100/150/200 m distance rings — geodesic polygons

## Principles

- High-contrast outdoor-readable style
- Dark base (`#0F172A`) with bright accent colors
- Course geometry from the local package; raster only where licensed satellite
  imagery exists
- Anything with a real-world radius (GPS accuracy, distance rings) is drawn as
  metric geometry, never as a pixel radius
- Sub-100ms layer toggle latency
