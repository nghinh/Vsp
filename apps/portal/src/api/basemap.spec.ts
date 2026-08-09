/**
 * Tests for the portal's satellite basemap.
 *
 * The geometry editor had a CARTO satellite style hardcoded, and CARTO removed
 * it — the URL answers 404. The Satellite button switched to a style that never
 * loaded, so the one job the editor exists for, tracing a fairway off an aerial
 * photo, could not be done at all. The provider now comes from the API, so the
 * portal and the phone draw the same imagery under one licence.
 */
import { describe, expect, it } from 'vitest';
import { baseStyleFrom, blankDarkStyle, rasterStyleFrom, type BasemapConfig } from './basemap';

function config(over: Partial<BasemapConfig> = {}): BasemapConfig {
  return {
    mapboxAccessToken: '',
    satelliteTileUrl: '',
    satelliteAttribution: '',
    satelliteMaxZoom: null,
    baseTileUrl: '',
    baseAttribution: '',
    baseMaxZoom: null,
    ...over,
  };
}

describe('rasterStyleFrom', () => {
  it('builds a raster style from an operator tile URL', () => {
    const style = rasterStyleFrom(
      config({
        satelliteTileUrl: 'https://tiles.example.vn/{z}/{y}/{x}',
        satelliteAttribution: '© Example',
        satelliteMaxZoom: 19,
      }),
    );
    const sources = (style as any).sources.satellite;
    expect(sources.tiles).toEqual(['https://tiles.example.vn/{z}/{y}/{x}']);
    // Most services stop short of 22; asking past the last level gets 404s and
    // a blank map at exactly the zoom somebody traces a bunker at.
    expect(sources.maxzoom).toBe(19);
    expect(sources.attribution).toBe('© Example');
  });

  it('refuses operator imagery that arrives without attribution', () => {
    // Same rule the mobile client applies. Imagery we cannot credit is
    // imagery we do not display.
    expect(
      rasterStyleFrom(config({ satelliteTileUrl: 'https://t/{z}/{y}/{x}' })),
    ).toBeNull();
  });

  it('falls back to Mapbox when a token is configured', () => {
    const style = rasterStyleFrom(config({ mapboxAccessToken: 'pk.abc' }));
    const source = (style as any).sources.satellite;
    expect(source.tiles[0]).toContain('pk.abc');
    expect(source.tileSize).toBe(512);
  });

  it('prefers operator imagery over Mapbox', () => {
    const style = rasterStyleFrom(
      config({
        mapboxAccessToken: 'pk.abc',
        satelliteTileUrl: 'https://own/{z}/{y}/{x}',
        satelliteAttribution: '© Own',
      }),
    );
    // A club running its own licensed orthophotos should not also pay Mapbox.
    expect((style as any).sources.satellite.tiles[0]).toBe('https://own/{z}/{y}/{x}');
  });

  it('returns null when nothing is configured', () => {
    // The editor keeps the dark basemap and disables the button, rather than
    // switching to a style that loads nothing.
    expect(rasterStyleFrom(config())).toBeNull();
    expect(rasterStyleFrom(null)).toBeNull();
  });
});

describe('baseStyleFrom', () => {
  it('draws its own canvas when nothing is configured', () => {
    // The default, and deliberately so: the editor used to hardcode CARTO's
    // dark-matter style, CARTO stopped serving it mid-session, and there was
    // no way to point it elsewhere without a release.
    const style = baseStyleFrom(config());
    expect(style.sources).toEqual({});
    expect(JSON.stringify(style)).not.toContain('http');
  });

  it('uses the configured tiles when they come with attribution', () => {
    const style = baseStyleFrom(
      config({ baseTileUrl: 'https://tiles.example/{z}/{x}/{y}.png', baseAttribution: '© Example' }),
    );
    const sources = style.sources as Record<string, { tiles: string[]; attribution: string }>;
    expect(sources.base.tiles).toEqual(['https://tiles.example/{z}/{x}/{y}.png']);
    expect(sources.base.attribution).toBe('© Example');
  });

  it('refuses tiles that arrive without attribution', () => {
    // Same rule as the imagery path. Tiles shown uncredited are tiles shown in
    // breach of whatever licence they came under.
    const style = baseStyleFrom(config({ baseTileUrl: 'https://tiles.example/{z}/{x}/{y}.png' }));
    expect(style.sources).toEqual({});
  });

  it('never returns null, so a map always has something to load', () => {
    expect(baseStyleFrom(null)).toEqual(blankDarkStyle());
  });
});
