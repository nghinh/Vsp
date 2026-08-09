/**
 * Point geometry in, point geometry out.
 *
 * Two jobs, and the second one exists because the API is not symmetric about
 * geometry. It *accepts* WKT — `POINT(lng lat)` — and depending on the
 * endpoint it *returns* either WKT or the hex EWKB PostGIS stores:
 *
 *   /admin/courses/{id}/pins    →  POINT(106.8960049 10.8612399)
 *   /admin/facilities, /courses →  0101000020E6100000FA0C…
 *
 * The pin map opened in the middle of the country because a reader that only
 * understood the first form quietly returned null for the second, and null
 * centre means fallback centre. It looked like a map bug and was a parsing
 * bug.
 *
 * The axis order is the other trap. WKT and EWKB both put longitude first;
 * every human-facing field, every map link and every conversation about a golf
 * course puts latitude first. Swapping them produces a valid point off the
 * coast of Somalia — in range, so no validation catches it.
 */

export interface Point {
  latitude: number;
  longitude: number;
}

/** `POINT(lng lat)` from a latitude and longitude. */
export function pointToWkt(latitude: number, longitude: number): string {
  return `POINT(${longitude} ${latitude})`;
}

const WKT_POINT = /^\s*POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)\s*$/i;

/** Latitude and longitude out of `POINT(lng lat)`, or null. */
export function wktToPoint(wkt: string | null | undefined): Point | null {
  const match = WKT_POINT.exec(wkt ?? '');
  if (!match) return null;
  return { longitude: Number(match[1]), latitude: Number(match[2]) };
}

/**
 * Latitude and longitude out of hex EWKB, or null.
 *
 * Layout for a point: one byte of endianness, four of type (the 0x20000000 bit
 * says an SRID follows), four of SRID when that bit is set, then two IEEE-754
 * doubles — X then Y, which is longitude then latitude.
 */
export function ewkbToPoint(hex: string | null | undefined): Point | null {
  const clean = (hex ?? '').trim();
  if (!/^[0-9a-fA-F]+$/.test(clean) || clean.length < 42) return null;

  const bytes = new Uint8Array(clean.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  const view = new DataView(bytes.buffer);

  const littleEndian = bytes[0] === 1;
  const type = view.getUint32(1, littleEndian);
  // Low bits carry the geometry type; 1 is Point. Anything else is a shape
  // with no single coordinate to hand back.
  if ((type & 0xff) !== 1) return null;

  const hasSrid = (type & 0x20000000) !== 0;
  const offset = hasSrid ? 9 : 5;
  if (bytes.length < offset + 16) return null;

  return {
    longitude: view.getFloat64(offset, littleEndian),
    latitude: view.getFloat64(offset + 8, littleEndian),
  };
}

/**
 * Whatever the API returned, as a point.
 *
 * Use this rather than either reader directly: which form a given endpoint
 * hands back is not something a caller should have to know, and it has already
 * caught one page out.
 */
export function parsePoint(value: string | null | undefined): Point | null {
  return wktToPoint(value) ?? ewkbToPoint(value);
}
