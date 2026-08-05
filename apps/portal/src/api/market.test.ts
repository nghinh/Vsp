/**
 * Unit tests for the Market & Integrations API client.
 * Per Story 12.4 — International Expansion (portal).
 */

import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { MarketApi } from '@/api/market';
import type {
  MarketListResponse,
  Market,
  MarketConfigResponse,
  DataLicenseListResponse,
  DataLicense,
  LicenseValidationResult,
} from '@/types/market';

const BASE = 'https://api.test';
const TOKEN = 'test-token';

function jsonResponse(body: unknown, ok = true, status = 200): Response {
  return {
    ok,
    status,
    statusText: ok ? 'OK' : 'Error',
    json: () => Promise.resolve(body),
  } as unknown as Response;
}

describe('MarketApi', () => {
  let api: MarketApi;
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    api = new MarketApi(BASE);
    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('lists markets and unwraps content', async () => {
    const body: MarketListResponse = {
      content: [
        { marketId: 'VN', name: 'Vietnam', active: true },
        { marketId: 'TH', name: 'Thailand', active: false },
      ],
      totalElements: 2,
    };
    fetchMock.mockResolvedValue(jsonResponse(body));

    const res = await api.listMarkets(TOKEN);

    expect(res.content).toHaveLength(2);
    expect(fetchMock).toHaveBeenCalledWith(
      `${BASE}/markets`,
      expect.objectContaining({
        headers: { Authorization: `Bearer ${TOKEN}` },
      })
    );
  });

  it('passes the active filter as a query param', async () => {
    fetchMock.mockResolvedValue(jsonResponse({ content: [] }));
    await api.listMarkets(TOKEN, true);
    expect(fetchMock).toHaveBeenCalledWith(`${BASE}/markets?active=true`, expect.anything());
  });

  it('fetches resolved market config', async () => {
    const config: MarketConfigResponse = {
      marketId: 'VN',
      locale: 'vi-VN',
      language: 'vi',
      units: 'METRIC',
      timezone: 'Asia/Ho_Chi_Minh',
      currency: 'VND',
      dateFormat: 'dd/MM/yyyy',
      retentionPolicyDays: 365,
      forkGpsBehavior: false,
      forkScoreBehavior: false,
      redistributionRequiresLicense: false,
    };
    fetchMock.mockResolvedValue(jsonResponse(config));

    const res = await api.getMarketConfig(TOKEN, 'VN');

    expect(res.currency).toBe('VND');
    expect(fetchMock).toHaveBeenCalledWith(`${BASE}/markets/VN/config`, expect.anything());
  });

  it('upserts a market via PUT to the admin endpoint', async () => {
    const market: Market = {
      marketId: 'TH',
      name: 'Thailand',
      currencyCode: 'THB',
      measurementUnit: 'METRIC',
      timezone: 'Asia/Bangkok',
      defaultLanguage: 'th',
      active: true,
    };
    fetchMock.mockResolvedValue(jsonResponse(market));

    await api.upsertMarket(TOKEN, 'TH', market);

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE}/admin/markets/TH`);
    expect(init.method).toBe('PUT');
    expect(JSON.parse(init.body)).toMatchObject({ marketId: 'TH', currencyCode: 'THB' });
  });

  it('upserts market config via PUT', async () => {
    fetchMock.mockResolvedValue(jsonResponse({ marketId: 'VN' }));
    await api.upsertMarketConfig(TOKEN, 'VN', {
      marketId: 'VN',
      redistributionRequiresLicense: true,
    });
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE}/admin/markets/VN/config`);
    expect(init.method).toBe('PUT');
    expect(JSON.parse(init.body).redistributionRequiresLicense).toBe(true);
  });

  it('lists licenses and unwraps the content array', async () => {
    const lic: DataLicense = {
      licenseId: 'lic-1',
      name: 'CC BY 4.0',
      spdxId: 'CC-BY-4.0',
      redistributionMarkets: ['VN', 'TH'],
      issuedAt: '2026-01-01T00:00:00Z',
      valid: true,
    };
    const body: DataLicenseListResponse = { content: [lic] };
    fetchMock.mockResolvedValue(jsonResponse(body));

    const res = await api.listLicenses(TOKEN);

    expect(res).toHaveLength(1);
    expect(res[0].spdxId).toBe('CC-BY-4.0');
  });

  it('creates a license via POST', async () => {
    fetchMock.mockResolvedValue(jsonResponse({ licenseId: 'lic-2' }, true, 201));
    await api.createLicense(TOKEN, {
      name: 'MIT',
      spdxId: 'MIT',
      redistributionMarkets: ['VN'],
    });
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE}/admin/licenses`);
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body).redistributionMarkets).toEqual(['VN']);
  });

  it('validates redistribution and returns errors', async () => {
    const result: LicenseValidationResult = {
      isValid: false,
      errors: [
        {
          licenseId: 'lic-1',
          spdxId: 'CC-BY-NC-4.0',
          code: 'LICENSE_REDISTRIBUTION_NOT_ALLOWED',
          message: 'Redistribution not allowed for TH',
          targetMarket: 'TH',
        },
      ],
    };
    fetchMock.mockResolvedValue(jsonResponse(result));

    const res = await api.validateRedistribution(TOKEN, {
      targetMarket: 'TH',
      licenses: [{ spdxId: 'CC-BY-NC-4.0' }],
    });

    expect(res.isValid).toBe(false);
    expect(res.errors[0].code).toBe('LICENSE_REDISTRIBUTION_NOT_ALLOWED');
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(`${BASE}/admin/licenses/validate-redistribution`);
    expect(init.method).toBe('POST');
  });

  it('throws the parsed error body on non-ok responses', async () => {
    fetchMock.mockResolvedValue(
      jsonResponse({ code: 'FORBIDDEN', message: 'No access' }, false, 403)
    );
    await expect(api.listMarkets(TOKEN)).rejects.toMatchObject({
      code: 'FORBIDDEN',
      message: 'No access',
    });
  });
});
