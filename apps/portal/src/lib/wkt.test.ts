/**
 * The axis order, pinned.
 *
 * WKT is longitude-first and everything a human says about a golf course is
 * latitude-first. A swap is not caught by validation — both numbers stay in
 * range — and it does not look wrong on screen. It puts the pin in the Indian
 * Ocean, and the app cheerfully quotes the distance to it.
 *
 * The coordinates below are hole 10 at Long Thành. Latitude ~10.86 and
 * longitude ~106.90 are far enough apart that a swap is unmistakable here, and
 * that is deliberate: a test written at a place where the two are similar
 * would pass either way.
 */

import { describe, expect, it } from 'vitest';

import { ewkbToPoint, parsePoint, pointToWkt, wktToPoint } from './wkt';

const LAT = 10.8612399;
const LNG = 106.8960049;

describe('pointToWkt', () => {
  it('writes longitude first, as WKT requires', () => {
    expect(pointToWkt(LAT, LNG)).toBe('POINT(106.8960049 10.8612399)');
  });

  it('keeps negative coordinates intact', () => {
    expect(pointToWkt(-33.8688, 151.2093)).toBe('POINT(151.2093 -33.8688)');
  });
});

describe('wktToPoint', () => {
  it('reads longitude first, as WKT requires', () => {
    expect(wktToPoint('POINT(106.8960049 10.8612399)')).toEqual({
      latitude: LAT,
      longitude: LNG,
    });
  });

  it('round-trips', () => {
    expect(wktToPoint(pointToWkt(LAT, LNG))).toEqual({
      latitude: LAT,
      longitude: LNG,
    });
  });

  it('tolerates the whitespace a server might emit', () => {
    expect(wktToPoint('  POINT ( 106.896 10.861 )  ')).toEqual({
      latitude: 10.861,
      longitude: 106.896,
    });
  });

  it('handles negatives', () => {
    expect(wktToPoint('POINT(-0.1278 51.5074)')).toEqual({
      latitude: 51.5074,
      longitude: -0.1278,
    });
  });

  it('returns null rather than guessing at anything that is not a point', () => {
    // A polygon, an empty string and a null all reach this from the API. None
    // of them should produce a coordinate — a wrong pin is worse than none.
    expect(wktToPoint('POLYGON((0 0, 1 1, 1 0, 0 0))')).toBeNull();
    expect(wktToPoint('')).toBeNull();
    expect(wktToPoint(null)).toBeNull();
    expect(wktToPoint(undefined)).toBeNull();
    expect(wktToPoint('POINT(106.896)')).toBeNull();
  });
});

describe('ewkbToPoint', () => {
  // What /admin/facilities and /admin/courses/{id} actually return for
  // Sky Lake: little-endian, type 0x20000001 (point with SRID), SRID 4326,
  // then longitude and latitude as doubles.
  const SKY_LAKE = '0101000020E6100000FA0CA837A3675A4028F96C78D5D63440';

  it('reads the form the course endpoints return', () => {
    const at = ewkbToPoint(SKY_LAKE);
    expect(at).not.toBeNull();
    expect(at!.longitude).toBeCloseTo(105.61934, 4);
    expect(at!.latitude).toBeCloseTo(20.83919, 4);
  });

  it('puts longitude first, as the encoding does', () => {
    // Reversed, this is a spot in the Indian Ocean and the map opens there
    // without complaint.
    const at = ewkbToPoint(SKY_LAKE)!;
    expect(at.longitude).toBeGreaterThan(at.latitude);
  });

  it('refuses anything that is not a point', () => {
    expect(ewkbToPoint('POINT(1 2)')).toBeNull();
    expect(ewkbToPoint('')).toBeNull();
    expect(ewkbToPoint(null)).toBeNull();
    expect(ewkbToPoint('0101000020E610')).toBeNull();
    expect(ewkbToPoint('0103000020E6100000000000000000000000000000')).toBeNull();
  });
});

describe('parsePoint', () => {
  it('accepts either form, because the API returns both', () => {
    const fromWkt = parsePoint('POINT(105.61934 20.83919)')!;
    const fromEwkb = parsePoint('0101000020E6100000FA0CA837A3675A4028F96C78D5D63440')!;

    expect(fromWkt.latitude).toBeCloseTo(fromEwkb.latitude, 4);
    expect(fromWkt.longitude).toBeCloseTo(fromEwkb.longitude, 4);
  });

  it('is null for anything else', () => {
    expect(parsePoint('not geometry')).toBeNull();
    expect(parsePoint(undefined)).toBeNull();
  });
});
