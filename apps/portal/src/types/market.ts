/**
 * TypeScript types for the Market & Integrations API.
 * Mirror the backend DTOs from Story 12.4 (International Expansion).
 *
 * Contract: packages/contracts/schemas/market.yaml
 */

// ─── Enums ─────────────────────────────────────────────────────────────────

export type MeasurementUnitValue = 'METRIC' | 'IMPERIAL';

export type LicenseValidationCodeValue =
  | 'LICENSE_REDISTRIBUTION_NOT_ALLOWED'
  | 'LICENSE_NOT_FOUND'
  | 'LICENSE_EXPIRED';

// ─── Market ─────────────────────────────────────────────────────────────────

export interface Market {
  /** ISO 3166-1 alpha-2 country code (read-only). */
  marketId: string;
  name: string;
  currencyCode?: string | null;
  dateFormat?: string | null;
  measurementUnit?: MeasurementUnitValue | null;
  timezone?: string | null;
  defaultLanguage?: string | null;
  active: boolean;
}

export interface MarketListResponse {
  content: Market[];
  page?: number;
  size?: number;
  totalElements?: number;
  totalPages?: number;
}

// ─── Market Config ────────────────────────────────────────────────────────────

export interface MarketConfig {
  marketId: string;
  forkGpsBehavior?: boolean | null;
  forkScoreBehavior?: boolean | null;
  redistributionRequiresLicense?: boolean | null;
}

/** Fully resolved config with Vietnam defaults filled in for unset fields. */
export interface MarketConfigResponse {
  marketId: string;
  locale: string;
  language: string;
  units: MeasurementUnitValue;
  timezone: string;
  currency: string;
  dateFormat: string;
  rulesUrl?: string | null;
  enabledProviderIds?: string[] | null;
  requiredLicenseIds?: string[] | null;
  retentionPolicyDays: number;
  forkGpsBehavior: boolean;
  forkScoreBehavior: boolean;
  redistributionRequiresLicense: boolean;
}

// ─── Data License ─────────────────────────────────────────────────────────────

export interface DataLicense {
  /** Unique license identifier (read-only). */
  licenseId: string;
  name: string;
  spdxId: string;
  licensee?: string | null;
  redistributionMarkets: string[];
  issuedAt: string;
  expiresAt?: string | null;
  valid: boolean;
}

export interface DataLicenseListResponse {
  content: DataLicense[];
}

export interface DataLicenseCreateRequest {
  name: string;
  spdxId: string;
  licensee?: string | null;
  redistributionMarkets: string[];
  expiresAt?: string | null;
}

// ─── License Validation ────────────────────────────────────────────────────────

export interface LicenseSpdxEntry {
  spdxId: string;
  licenseId?: string | null;
}

export interface ValidateRedistributionRequest {
  targetMarket: string;
  licenses: LicenseSpdxEntry[];
}

export interface LicenseValidationError {
  licenseId?: string;
  spdxId?: string;
  code: LicenseValidationCodeValue;
  message: string;
  targetMarket?: string;
}

export interface LicenseValidationResult {
  isValid: boolean;
  errors: LicenseValidationError[];
}

// ─── Error ─────────────────────────────────────────────────────────────────

export interface MarketApiError {
  code: string;
  message: string;
  correlationId?: string;
  field?: string;
}
