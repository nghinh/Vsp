/**
 * Where the portal's satellite basemap comes from.
 *
 * The geometry editor had `https://basemaps.cartocdn.com/gl/satellite-gl-style/
 * style.json` hardcoded, and CARTO has removed it — the URL answers 404. So the
 * editor's "Satellite" button switched to a style that never loaded, and the
 * one job the editor exists for, tracing a fairway off an aerial photo, could
 * not be done at all.
 *
 * Reading the provider from the API instead means the portal and the phone draw
 * the same imagery, under one licence, configured in one place, revocable in
 * one place.
 */
import { getAuthToken } from '../auth';
import { API_BASE } from './base';

const BASE = API_BASE;

export interface BasemapConfig {
  mapboxAccessToken: string;
  satelliteTileUrl: string;
  satelliteAttribution: string;
  satelliteMaxZoom: number | null;
  /** The non-imagery basemap. Empty means the client draws its own. */
  baseTileUrl: string;
  baseAttribution: string;
  baseMaxZoom: number | null;
}

/** A MapLibre style with one raster layer, or null when nothing is configured. */
export type RasterStyle = Record<string, unknown> | null;

export async function fetchBasemapConfig(): Promise<BasemapConfig | null> {
  try {
    const res = await fetch(`${BASE}/config/basemap`, {
      headers: { Authorization: `Bearer ${getAuthToken()}` },
    });
    if (!res.ok) return null;
    return (await res.json()) as BasemapConfig;
  } catch {
    // Imagery is an enhancement. The editor still works over the dark basemap,
    // and saying so is better than a blank canvas.
    return null;
  }
}

/**
 * Turns the configured provider into a style the editor can load.
 *
 * Mirrors the mobile client's rules deliberately: an operator tile URL wins
 * over Mapbox, and imagery that arrives without attribution is refused rather
 * than displayed uncredited.
 */
export function rasterStyleFrom(config: BasemapConfig | null): RasterStyle {
  if (!config) return null;

  const custom = config.satelliteTileUrl?.trim() ?? '';
  const credit = config.satelliteAttribution?.trim() ?? '';
  const token = config.mapboxAccessToken?.trim() ?? '';

  let tiles: string;
  let attribution: string;
  let tileSize: number;
  let maxzoom: number;

  if (custom && credit) {
    tiles = custom;
    attribution = credit;
    tileSize = 256;
    maxzoom = config.satelliteMaxZoom ?? 22;
  } else if (token) {
    tiles =
      `https://api.mapbox.com/v4/mapbox.satellite/{z}/{x}/{y}@2x.jpg90` +
      `?access_token=${token}`;
    attribution = '© Mapbox © OpenStreetMap';
    tileSize = 512;
    maxzoom = 22;
  } else {
    return null;
  }

  return {
    version: 8,
    name: 'VSP Satellite',
    sources: {
      satellite: { type: 'raster', tiles: [tiles], tileSize, maxzoom, attribution },
    },
    layers: [
      { id: 'background', type: 'background', paint: { 'background-color': '#0F172A' } },
      { id: 'satellite', type: 'raster', source: 'satellite', paint: { 'raster-opacity': 1 } },
    ],
  };
}

/**
 * A flat dark canvas, drawn locally.
 *
 * No sources, no tiles, no third party. This is what the editor sits on when
 * no plain basemap is configured, and it is a reasonable default rather than a
 * degraded one: tracing a fairway is done against satellite imagery, and the
 * layer behind the shapes only needs to not be white.
 */
export function blankDarkStyle(): Record<string, unknown> {
  return {
    version: 8,
    name: 'VSP Base',
    sources: {},
    layers: [
      { id: 'background', type: 'background', paint: { 'background-color': '#0F172A' } },
    ],
  };
}

/**
 * The configured plain basemap, or the local canvas.
 *
 * Never null and never a hardcoded URL — which is the point. CARTO's
 * dark-matter style was compiled into two components; CARTO stopped serving it
 * during a working session and both maps went blank with no way to change the
 * source short of a release. Attribution is required for the same reason it is
 * on the imagery path: tiles shown uncredited are tiles shown in breach.
 */
export function baseStyleFrom(config: BasemapConfig | null): Record<string, unknown> {
  const tiles = config?.baseTileUrl?.trim() ?? '';
  const credit = config?.baseAttribution?.trim() ?? '';
  if (!tiles || !credit) return blankDarkStyle();

  return {
    version: 8,
    name: 'VSP Base',
    sources: {
      base: {
        type: 'raster',
        tiles: [tiles],
        tileSize: 256,
        maxzoom: config?.baseMaxZoom ?? 19,
        attribution: credit,
      },
    },
    layers: [
      { id: 'background', type: 'background', paint: { 'background-color': '#0F172A' } },
      { id: 'base', type: 'raster', source: 'base' },
    ],
  };
}
