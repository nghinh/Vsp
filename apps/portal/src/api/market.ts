/**
 * Market & Integrations API client for the VSP Portal.
 *
 * Per Story 12.4 — International Expansion.
 *
 * Endpoints:
 *   GET  /markets                                      — list markets (?active)
 *   GET  /markets/{marketId}                           — get a market
 *   GET  /markets/{marketId}/config                    — resolved config (Vietnam defaults filled in)
 *   GET  /admin/markets                                — list markets (admin)
 *   PUT  /admin/markets/{marketId}                     — create/update a market
 *   PUT  /admin/markets/{marketId}/config              — create/update market config
 *   GET  /admin/licenses                               — list data licenses
 *   POST /admin/licenses                               — create a data license
 *   POST /admin/licenses/validate-redistribution       — validate redistribution for a market
 */

import type {
  Market,
  MarketListResponse,
  MarketConfig,
  MarketConfigResponse,
  DataLicense,
  DataLicenseListResponse,
  DataLicenseCreateRequest,
  ValidateRedistributionRequest,
  LicenseValidationResult,
} from '@/types/market';

const BASE = import.meta.env.VITE_API_BASE_URL ?? 'https://api.vsp.local';

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const err = await res.json().catch(() => ({
      code: 'UNKNOWN',
      message: res.statusText,
    }));
    throw err;
  }
  return res.json() as Promise<T>;
}

export class MarketApi {
  constructor(private baseUrl: string = BASE) {}

  // ─── Markets ────────────────────────────────────────────────────────────

  async listMarkets(token: string, active?: boolean): Promise<MarketListResponse> {
    const query = active === undefined ? '' : `?active=${active}`;
    const res = await fetch(`${this.baseUrl}/markets${query}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<MarketListResponse>(res);
  }

  async getMarket(token: string, marketId: string): Promise<Market> {
    const res = await fetch(`${this.baseUrl}/markets/${marketId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<Market>(res);
  }

  async getMarketConfig(token: string, marketId: string): Promise<MarketConfigResponse> {
    const res = await fetch(`${this.baseUrl}/markets/${marketId}/config`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<MarketConfigResponse>(res);
  }

  // ─── Admin: markets ──────────────────────────────────────────────────────

  async upsertMarket(token: string, marketId: string, market: Market): Promise<Market> {
    const res = await fetch(`${this.baseUrl}/admin/markets/${marketId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(market),
    });
    return handleResponse<Market>(res);
  }

  async upsertMarketConfig(
    token: string,
    marketId: string,
    config: MarketConfig
  ): Promise<MarketConfig> {
    const res = await fetch(`${this.baseUrl}/admin/markets/${marketId}/config`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(config),
    });
    return handleResponse<MarketConfig>(res);
  }

  // ─── Admin: licenses ─────────────────────────────────────────────────────

  async listLicenses(token: string): Promise<DataLicense[]> {
    const res = await fetch(`${this.baseUrl}/admin/licenses`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const body = await handleResponse<DataLicenseListResponse>(res);
    return body.content ?? [];
  }

  async createLicense(
    token: string,
    request: DataLicenseCreateRequest
  ): Promise<DataLicense> {
    const res = await fetch(`${this.baseUrl}/admin/licenses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<DataLicense>(res);
  }

  async validateRedistribution(
    token: string,
    request: ValidateRedistributionRequest
  ): Promise<LicenseValidationResult> {
    const res = await fetch(`${this.baseUrl}/admin/licenses/validate-redistribution`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<LicenseValidationResult>(res);
  }
}

export const marketApi = new MarketApi();
