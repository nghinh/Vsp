/**
 * TypeScript types for Tournament Policy API.
 * Mirror the backend DTOs from Story 7.4 Slice E.
 */

/** Feature flags that can be toggled in a tournament policy. */
export interface TournamentPolicyFeatureFlags {
  windAdjustmentEnabled: boolean;
  playsLikeEnabled: boolean;
  elevationEnabled: boolean;
  clubRecommendationEnabled: boolean;
  contoursEnabled: boolean;
  puttingHelpEnabled: boolean;
  aiFeaturesEnabled: boolean;
}

/** Full tournament policy response DTO. */
export interface TournamentPolicyResponse extends TournamentPolicyFeatureFlags {
  id: string;               // UUID
  name: string;
  description: string | null;
  isLocked: boolean;
  createdAt: string;        // ISO-8601
  createdBy: number;        // account ID
  version: number;
}

/** Request to create a new tournament policy. */
export interface TournamentPolicyCreateRequest {
  name: string;
  description?: string;
  windAdjustmentEnabled: boolean;
  playsLikeEnabled: boolean;
  elevationEnabled: boolean;
  clubRecommendationEnabled: boolean;
  contoursEnabled: boolean;
  puttingHelpEnabled: boolean;
  aiFeaturesEnabled: boolean;
}

/** Request to update an existing tournament policy (partial update). */
export interface TournamentPolicyUpdateRequest {
  name?: string;
  description?: string | null;
  windAdjustmentEnabled?: boolean;
  playsLikeEnabled?: boolean;
  elevationEnabled?: boolean;
  clubRecommendationEnabled?: boolean;
  contoursEnabled?: boolean;
  puttingHelpEnabled?: boolean;
  aiFeaturesEnabled?: boolean;
}

/** A single change record from the audit timeline. */
export interface TournamentPolicyChangeDto {
  id: string;
  policyId: string;
  changedBy: number;       // account ID
  changedByName?: string;  // display name if available
  changedAt: string;       // ISO-8601
  reason: string | null;
  beforeJson: string | null;   // JSON string of flags before
  afterJson: string | null;     // JSON string of flags after
}

/** API error response shape. */
export interface ApiError {
  code: string;
  message: string;
  correlationId?: string;
  field?: string;
  details?: Record<string, unknown>;
}
